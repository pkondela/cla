# Claude Code + Free modely + DeepSeek

Kompletny balicek pre nastavenie Claude Code s podporou:
- **Claude modely** (Sonnet/Opus/Haiku) -- priamo na Anthropic API
- **DeepSeek modely** (V4 Flash, V4 Pro) -- priamo na DeepSeek API
- **Free modely** (Nemotron, Hermes, Qwen, Kimi, Gemma, Llama, GLM, GPT-OSS) -- cez OpenRouter
- **Plateny model** (Devstral 2) -- cez OpenRouter (vyzaduje kredity)

## Struktura

```
start.sh                <- HLAVNY start (zip root, rozbali + spusti install.sh)
claude-migration/
├── start.sh            <- Jednoduchy wrapper (spusti install.sh z vnutra priecinka)
├── install.sh          <- Interaktivna instalacia (API kluce + gateway + config + .bashrc)
├── auto-setup.sh       <- Univerzalny wrapper (rozbali zip ak treba + spusti install.sh)
├── README.md
├── llm-gateway/
│   ├── docker-compose.yml
│   ├── litellm-config.yaml    - 11 modelov pre OpenRouter (10 free + 1 paid)
│   ├── .env.template
│   ├── router/
│   │   ├── Dockerfile
│   │   └── app.py             - Routing: deepseek→DeepSeek anthropic API, free→LiteLLM→OpenRouter, ostatne→Anthropic
│   └── README.md
└── claude-config/
    ├── settings.json
    └── projects/
```

## Instalacia

### 1. Rychly start (odporucane)
```bash
chmod +x start.sh
./start.sh
```

Skript automaticky:
1. Overi/nainstaluje **Node.js + npm**
2. Overi/nainstaluje **Claude Code** (cez npm)
3. Overi/nainstaluje **Docker**
4. Spusti **interaktivne zadanie API klucov** (Anthropic + OpenRouter + DeepSeek)
5. **Overi format klucov**
6. Spusti Docker LLM Gateway
7. **Overi gateway healthcheck + /v1/models endpoint**
8. Nakopiruje konfiguraciu do `~/.claude/`
9. **Nastavi premenne prostredia v `~/.bashrc`** (ANTHROPIC_BASE_URL, model discovery, claude-direct alias)

Po dokonceni: `source ~/.bashrc` (alebo otvorte novy terminal)

### 2. Manualna (ak uz mate .env pripraveny)
```bash
./claude-migration/install.sh
```

### 3. Poziadavky
- **Docker** a Docker Compose
- **Bash shell**
- **Node.js 18+** (pre Claude Code -- `start.sh` nainstaluje automaticky)

## API kluce

Instalacia si ich vypyta interaktivne. Potrebujete:

| Kluc | Kde ziskat | Povinny | Pre |
|------|-----------|---------|-----|
| Anthropic API Key | https://console.anthropic.com/ | yes | Claude Sonnet/Opus/Haiku |
| OpenRouter API Key | https://openrouter.ai/keys | yes | Free modely + Devstral 2 |
| DeepSeek API Key | https://platform.deepseek.com/ | no | DeepSeek V4 Flash/V4 Pro |

LiteLLM Master Key a Gateway Token sa vygeneruju automaticky (mozete zadat vlastne).

## Dostupne modely (13)

### DeepSeek -- natívny Anthropic endpoint (api.deepseek.com/anthropic)
| Model | Claude ID | Realny model |
|-------|-----------|-------------|
| DeepSeek V4 Flash | `claude-deepseek-v4-flash` | deepseek-v4-flash |
| DeepSeek V4 Pro | `claude-deepseek-v4-pro` | deepseek-v4-pro |

### Free -- cez OpenRouter (zadarmo, len rate-limit)
| Model | Claude ID | Parametre |
|-------|-----------|-----------|
| Nemotron 3 Ultra | `claude-free-nemotron-3-ultra` | 550B A55B |
| Nemotron 3 Super | `claude-free-nemotron-3-super` * | 120B A12B |
| Hermes 3 405B | `claude-free-hermes-3-405b` | 405B |
| Qwen3 Coder | `claude-free-qwen3-coder` | 480B A35B |
| Kimi K2.6 | `claude-free-kimi-k2.6` | ~200B |
| Gemma 4 31B | `claude-free-gemma-4-31b` | 31B |
| Llama 3.3 70B | `claude-free-llama-3.3-70b` | 70B |
| GLM 4.5 Air | `claude-free-glm-4.5-air` | ~30B |
| Qwen3 Next 80B | `claude-free-qwen3-next-80b` | 80B A3B |
| GPT-OSS 120B | `claude-free-gpt-oss-120b` | 120B |

### Paid -- cez OpenRouter (vyzaduje kredity)
| Model | Claude ID | Cena |
|-------|-----------|------|
| Devstral 2 | `claude-free-devstral-2` | ~$0.40/M in, $2/M out |

### Claude -- priamo na Anthropic API
Vstavane modely (Sonnet 4.8, Opus 4.8, Haiku 4.5) -- netreba nic prepinat.

## Routing

```
                    ┌─ claude-deepseek-*   → RAW passthrough → api.deepseek.com/anthropic
Claude Code ─► Router ─ claude-free-*       → LiteLLM → OpenRouter
                    └─ ostatne (claude-*)    → RAW passthrough → api.anthropic.com
```

**DeepSeek V4 ide priamo na natívny Anthropic endpoint DeepSeeku**
(`https://api.deepseek.com/anthropic`) -- bit-for-bit passthrough s `x-api-key`,
presne ako Anthropic. Router prepise nazov modelu (`claude-deepseek-v4-pro` →
`deepseek-v4-pro`), aby DeepSeek ticho nenamapoval Pro na Flash. Tento sposob
oficialne odporuca DeepSeek pre Claude Code (zachova thinking, tool use, streaming).

Anthropic modely idu tiez **bit-for-bit passthrough** (prompt caching, tool use, streaming, betas -- vsetko zachovane).
Iba free/paid modely idu cez LiteLLM (Anthropic ↔ OpenAI preklad pre OpenRouter).

## Pouzitie

```bash
claude                              # spustenie
/model                              # zoznam vsetkych modelov
/model claude-deepseek-v4-flash     # prepnutie na DeepSeek V4 Flash
/model claude-deepseek-v4-pro       # prepnutie na DeepSeek V4 Pro
/model claude-free-nemotron-3-super # prepnutie na Nemotron 3 Super
/model claude-sonnet-4-6            # prepnutie na Claude Sonnet

claude-direct                       # priame volanie Anthropic API (obchadza gateway)
```

## Sprava gatewayu

```bash
# Logy (sledovat routing decisions)
cd llm-gateway && docker compose logs -f router

# Restart
cd llm-gateway && docker compose restart

# Zastavenie
cd llm-gateway && docker compose down

# Rebuild po zmene modelov
cd llm-gateway && docker compose up -d --build

# Stav
docker ps | grep llm-gateway
```

## Fallbacky

- **Free modely**: fallback na ostatne free modely (nikdy nie na platene)
- **Platene modely**: fallback na free modely (pri chybe/rate-limit)
- **DeepSeek modely**: fallback nemaju (idu priamo na DeepSeek anthropic API)
- **Anthropic modely**: fallback nemaju (idu priamo)

## Pridanie novych modelov

**Free / paid (OpenRouter):**
1. Pridajte do `llm-gateway/litellm-config.yaml` (model_name musi zacinat na `claude-`)
2. Pridajte do `FREE_MODELS` alebo `PAID_MODELS` v `router/app.py`
3. Rebuild: `cd llm-gateway && docker compose up -d --build`

**DeepSeek (natívny endpoint, NIE cez litellm):**
1. Pridajte do `DEEPSEEK_MODELS` v `router/app.py` (Claude ID = `claude-` + realny DeepSeek model id)
2. Rebuild: `cd llm-gateway && docker compose up -d --build router`

## Riesenie problemov

### Gateway nebezi
```bash
cd llm-gateway && docker compose logs
```

### Free modely nefunguju
- Overte OpenRouter kluc: https://openrouter.ai/dashboard
- Logy: `docker compose logs -f router`
- Po starte gatewayu chvilu pockajte

### DeepSeek nefunguje
- Bol zadany DeepSeek API kluc pocas instalacie?
- Overte v `llm-gateway/.env`: `DEEPSEEK_API_KEY=...`
- **DeepSeek ide priamo na api.deepseek.com** -- overte, ci mate kredity na DeepSeek ucte
- Logy: `docker compose logs -f litellm`

### Claude modely nefunguju
- Gateway musi bezat (aj na Anthropic modely!)
- `docker ps | grep llm-gateway`

### Premenne prostredia nefunguju
- Spustite: `source ~/.bashrc`
- Overte: `echo $ANTHROPIC_BASE_URL` (malo by zobrazit `http://127.0.0.1:4000`)

## Bezpecnost
- `.env` je po instalacii automaticky `chmod 600`
- Gateway pocuva len na `127.0.0.1:4000`
- API kluce su len na serveri, nie v klientskej konfiguracii
- Router ignoruje autentifikaciu z Claude Code klienta -- kluce su pevne v `.env`

## Aktualizacia
Stiahnite novu verziu balicka a spustite:
```bash
./start.sh
```
