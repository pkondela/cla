---
name: llm-gateway
description: Local LLM gateway that adds DeepSeek V4, free OpenRouter models, and paid models to the Claude Code /model picker
metadata: 
  node_type: memory
  type: project
  originSessionId: afa3ddee-0fad-4ea7-82a9-e9af8ead6f71
---

User runs a local gateway at `~/llm-gateway` (Docker Compose) so the Claude Code `/model`
picker shows DeepSeek V4, free OpenRouter models, and paid models alongside Opus/Sonnet/Haiku.

Architecture: a small Python `router` (127.0.0.1:4000) serves `GET /v1/models` (static
Anthropic-format list of all model ids) and routes `POST /v1/messages` by prefix:
- `claude-deepseek-*` → RAW passthrough to api.deepseek.com/anthropic (DeepSeek's native
  Anthropic endpoint, x-api-key). Router rewrites model id (strips `claude-` prefix) so
  Pro isn't silently remapped to Flash. NOT through LiteLLM.
- `claude-free-*` → LiteLLM → OpenRouter (free/paid models)
- everything else (claude-sonnet/opus/haiku) → RAW passthrough to api.anthropic.com

The real ANTHROPIC_API_KEY, OPENROUTER_API_KEY, and DEEPSEEK_API_KEY live only
server-side in `~/llm-gateway/.env`. Claude Code wiring is in `~/.bashrc`:
`ANTHROPIC_BASE_URL=http://127.0.0.1:4000` and `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`,
plus a `claude-direct` shell function to bypass the gateway.

ANTHROPIC_AUTH_TOKEN is set to the gateway token so Claude Code sends an auth header;
the router ignores the client auth header and uses server-side keys instead.

Anthropic AND DeepSeek traffic are both byte-for-byte passthrough (prompt caching / tool use /
betas / thinking intact). DeepSeek uses its native Anthropic endpoint api.deepseek.com/anthropic —
NOT OpenRouter and NOT LiteLLM. Only free/paid OpenRouter models go through LiteLLM (Anthropic↔OpenAI).

Key facts: discovery needs ids starting with `claude`; built-in models always remain.
Current models (as of 2026-06):
- DeepSeek (2): deepseek-v4-flash, deepseek-v4-pro — directly to DeepSeek API
- Free via OpenRouter (10): nemotron-3-ultra, nemotron-3-super, hermes-3-405b, qwen3-coder,
  kimi-k2.6, gemma-4-31b, llama-3.3-70b, glm-4.5-air, qwen3-next-80b, gpt-oss-120b
- Paid via OpenRouter (1): devstral-2 (~$0.40/M in)

Installation is fully self-contained: install.sh checks/installs Node.js, npm, Claude Code,
Docker, then interactively prompts for API keys (Anthropic + OpenRouter + DeepSeek),
starts the gateway, verifies /v1/models endpoint, copies config to ~/.claude/,
and sets up environment variables in ~/.bashrc (ANTHROPIC_BASE_URL,
CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY, ANTHROPIC_AUTH_TOKEN, claude-direct).
