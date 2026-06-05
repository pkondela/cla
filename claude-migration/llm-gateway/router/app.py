"""Tiny routing proxy in front of LiteLLM + native Anthropic upstreams.

- GET  /v1/models   -> static Anthropic-format list of all models, so Claude
                       Code gateway discovery can populate the /model picker.
- POST /v1/messages -> model routing by prefix:
    claude-deepseek-*   -> RAW passthrough to DeepSeek's native Anthropic endpoint
                           (https://api.deepseek.com/anthropic). The model id is
                           rewritten by stripping the "claude-" prefix
                           (claude-deepseek-v4-pro -> deepseek-v4-pro) so DeepSeek
                           does NOT silently remap unknown ids to v4-flash.
    claude-free-*       -> LiteLLM -> OpenRouter (free / paid models)
    anything else       -> RAW passthrough to api.anthropic.com (Claude models)

DeepSeek and Anthropic both speak native Anthropic format with the `x-api-key`
header, so those routes are byte-for-byte passthrough (thinking, tool use,
streaming preserved). Only the DeepSeek route rewrites the `model` field in the
body; everything else is forwarded unchanged.
"""
import os
import json
import logging

from aiohttp import web, ClientSession, ClientTimeout

logging.basicConfig(level=logging.INFO, format="%(asctime)s router %(message)s")
log = logging.getLogger("router")

ANTHROPIC_BASE = "https://api.anthropic.com"
DEEPSEEK_BASE = "https://api.deepseek.com/anthropic"
LITELLM_BASE = os.environ.get("LITELLM_BASE", "http://litellm:4000")
ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
LITELLM_KEY = os.environ.get("LITELLM_MASTER_KEY", "sk-gateway-local")

# (model id exposed to Claude Code, human display name). The id MUST start with
# "claude" or Claude Code will filter it out of the picker.

# ---- DeepSeek V4 — natívny Anthropic endpoint (api.deepseek.com/anthropic) ----
DEEPSEEK_MODELS = [
    ("claude-deepseek-v4-flash", "DeepSeek V4 Flash"),
    ("claude-deepseek-v4-pro",   "DeepSeek V4 Pro"),
]

# ---- OpenRouter free modely (zadarmo, bez nutnosti kreditov) ----
FREE_MODELS = [
    ("claude-free-nemotron-3-ultra",  "Nemotron 3 Ultra 550B (free)"),
    ("claude-free-nemotron-3-super",  "Nemotron 3 Super 120B (free)"),
    ("claude-free-hermes-3-405b",     "Hermes 3 405B (free)"),
    ("claude-free-qwen3-coder",       "Qwen3 Coder 480B (free)"),
    ("claude-free-kimi-k2.6",         "Kimi K2.6 (free)"),
    ("claude-free-gemma-4-31b",       "Gemma 4 31B (free)"),
    ("claude-free-llama-3.3-70b",     "Llama 3.3 70B (free)"),
    ("claude-free-glm-4.5-air",       "GLM 4.5 Air (free)"),
    ("claude-free-qwen3-next-80b",    "Qwen3 Next 80B (free)"),
    ("claude-free-gpt-oss-120b",      "GPT-OSS 120B (free)"),
]

# ---- Platené modely cez OpenRouter (vyžadujú kredity) ----
PAID_MODELS = [
    ("claude-free-devstral-2", "Devstral 2 (paid)"),
]

# All models in picker order: DeepSeek first, then free, then paid
ALL_MODELS = DEEPSEEK_MODELS + FREE_MODELS + PAID_MODELS

# headers we must not copy verbatim between client/upstream. content-encoding is
# dropped from the *response* because the router decompresses upstream bodies
# (auto_decompress=True) and serves plaintext -- critical for clean SSE streaming.
HOP = {
    "host", "content-length", "connection", "keep-alive",
    "transfer-encoding", "x-api-key", "authorization", "accept-encoding",
    "content-encoding",
}


async def handle_models(_request):
    data = [
        {"type": "model", "id": mid, "display_name": name,
         "created_at": "2026-01-01T00:00:00Z"}
        for mid, name in ALL_MODELS
    ]
    return web.json_response({
        "data": data,
        "has_more": False,
        "first_id": data[0]["id"] if data else None,
        "last_id": data[-1]["id"] if data else None,
    })


def _route(model: str):
    """Return (upstream_base, auth_header_dict, label) for the given model."""
    if model.startswith("claude-deepseek-"):
        return DEEPSEEK_BASE, {"x-api-key": DEEPSEEK_API_KEY}, "deepseek"
    if model.startswith("claude-free-"):
        return LITELLM_BASE, {"Authorization": f"Bearer {LITELLM_KEY}"}, "litellm"
    return ANTHROPIC_BASE, {"x-api-key": ANTHROPIC_API_KEY}, "anthropic"


async def handle_proxy(request):
    body = await request.read()
    model = ""
    payload = None
    if body:
        try:
            payload = json.loads(body)
            model = payload.get("model", "") or ""
        except Exception:
            pass

    base, auth, label = _route(model)

    # DeepSeek's native Anthropic endpoint expects the real DeepSeek model id and
    # silently remaps unknown ids to v4-flash. Strip the "claude-" prefix so
    # claude-deepseek-v4-pro -> deepseek-v4-pro (and -flash -> -flash). This is the
    # only route that mutates the body; re-serialise it for the upstream request.
    if label == "deepseek" and payload is not None:
        payload["model"] = model[len("claude-"):]
        body = json.dumps(payload).encode("utf-8")

    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP}
    headers.update(auth)

    url = base + request.rel_url.raw_path
    if request.rel_url.raw_query_string:
        url += "?" + request.rel_url.raw_query_string

    log.info("%s %s -> %s (model=%s)", request.method, request.rel_url.raw_path,
             label, model or "-")

    session = request.app["session"]
    timeout = ClientTimeout(total=None, sock_connect=30, sock_read=None)
    up = await session.request(request.method, url, data=body,
                               headers=headers, timeout=timeout)

    resp = web.StreamResponse(
        status=up.status,
        headers={k: v for k, v in up.headers.items() if k.lower() not in HOP},
    )
    await resp.prepare(request)
    try:
        async for chunk in up.content.iter_any():
            await resp.write(chunk)
    finally:
        up.release()
    await resp.write_eof()
    return resp


async def on_start(app):
    # decompress upstream so we forward plaintext (clean incremental SSE);
    # content-encoding is stripped from the response in HOP accordingly.
    app["session"] = ClientSession(auto_decompress=True)


async def on_clean(app):
    await app["session"].close()


def make_app():
    app = web.Application(client_max_size=1024 ** 3)
    app.router.add_get("/healthz", lambda r: web.json_response({"ok": True}))
    app.router.add_get("/v1/models", handle_models)
    app.router.add_route("*", "/{tail:.*}", handle_proxy)
    app.on_startup.append(on_start)
    app.on_cleanup.append(on_clean)
    return app


if __name__ == "__main__":
    web.run_app(make_app(), host="0.0.0.0", port=4000)
