#!/usr/bin/env bash
set -euo pipefail

# ============================================
#  Claude Code + LLM Gateway -- Kompletná Inštalácia
#  - Overí/nainštaluje Node.js, npm, Claude Code
#  - Interaktívne si vypýta API kľúče
#  - Spustí Docker LLM Gateway
#  - Nakopíruje konfiguráciu
#  - Nastaví premenné prostredia v ~/.bashrc
# ============================================

echo "========================================"
echo "  Claude Code + LLM Gateway -- Inštalácia"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- 1. Node.js + npm --------------------------------------------------
echo "📦 Kontrolujem Node.js a npm..."
if ! command -v node &> /dev/null; then
    echo "⚠️  Node.js nie je nainštalovaný. Inštalujem..."
    NODE_INSTALLED=false
    if command -v apt &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt install -y nodejs
        NODE_INSTALLED=true
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs npm
        NODE_INSTALLED=true
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm nodejs npm
        NODE_INSTALLED=true
    else
        echo "❌ Nepodarilo sa nainštalovať Node.js."
        echo "   Prosím nainštalujte manuálne: https://nodejs.org"
        exit 1
    fi
    if [ "$NODE_INSTALLED" = true ]; then
        echo "✅ Node.js $(node --version) nainštalovaný"
    fi
else
    echo "✅ Node.js $(node --version)"
fi

if ! command -v npm &> /dev/null; then
    echo "⚠️  npm nie je nainštalovaný. Inštalujem..."
    if command -v apt &> /dev/null; then
        sudo apt install -y npm
    else
        echo "❌ npm sa nepodarilo nainštalovať."
        exit 1
    fi
fi
echo "✅ npm $(npm --version)"

# --- 2. Claude Code ---------------------------------------------------
echo ""
echo "🤖 Kontrolujem Claude Code..."
if ! command -v claude &> /dev/null; then
    echo "⚠️  Claude Code nie je nainštalovaný. Inštalujem cez npm..."
    npm install -g @anthropic-ai/claude-code
    echo "✅ Claude Code úspešne nainštalovaný"
else
    echo "✅ Claude Code už je nainštalovaný ($(claude --version 2>/dev/null || echo '?"))"
fi

# --- 3. Docker ---------------------------------------------------------
echo ""
echo "🐳 Kontrolujem Docker..."
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker nie je nainštalovaný. Inštalujem..."
    if command -v apt &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
        echo "⚠️  Docker nainštalovaný. Pre účinnosť sa odhláste a znova prihláste."
        echo "   Potom spustite tento skript znova."
        exit 0
    else
        echo "❌ Docker sa nepodarilo nainštalovať. Skúste manuálne:"
        echo "   curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
fi
echo "✅ Docker nainštalovaný"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "⚠️  Docker Compose nie je nainštalovaný. Inštalujem..."
    if command -v apt &> /dev/null; then
        sudo apt install -y docker-compose-plugin 2>/dev/null || {
            echo "❌ Docker Compose sa nepodarilo nainštalovať."
            exit 1
        }
    else
        echo "❌ Docker Compose nie je k dispozícii."
        exit 1
    fi
fi
echo "✅ Docker Compose dostupný"

# --- 4. API KĽÚČE – interaktívne ---------------------------------------
echo ""
echo "============================================"
echo "  Zadajte svoje API kľúče"
echo "  (Ctrl+C pre zrušenie)"
echo "============================================"
echo ""

# Anthropic API Key -- povinný (pre Claude Sonnet/Opus/Haiku)
read -rp "🔑 Anthropic API Key (sk-ant-...): " ANTHROPIC_KEY
while [ -z "$ANTHROPIC_KEY" ]; do
    echo "❌ Povinné! Bez Anthropic kľúča nefungujú Claude modely."
    read -rp "🔑 Anthropic API Key: " ANTHROPIC_KEY
done

# OpenRouter API Key -- povinný (pre free modely)
read -rp "🔑 OpenRouter API Key (sk-or-v1-...): " OPENROUTER_KEY
while [ -z "$OPENROUTER_KEY" ]; do
    echo "❌ Povinné! Bez OpenRouter kľúča nefungujú free modely."
    read -rp "🔑 OpenRouter API Key: " OPENROUTER_KEY
done

# DeepSeek API Key -- voliteľný (bez neho DeepSeek nefungujú, ale free/Claude áno)
read -rp "🔑 DeepSeek API Key (sk-..., nechajte prázdne ak nemáte): " DEEPSEEK_KEY
if [ -z "$DEEPSEEK_KEY" ]; then
    echo "   ⚠️  DeepSeek V4 Flash a V4 Pro nebudú dostupné."
    echo "   Kľúč môžete neskôr doplniť do llm-gateway/.env"
fi

# LiteLLM Master Key -- voliteľný, auto-generácia
read -rp "🔧 LiteLLM Master Key (nechajte prázdne pre auto-generáciu): " LITELLM_KEY
if [ -z "$LITELLM_KEY" ]; then
    LITELLM_KEY="sk-litellm-$(openssl rand -hex 16 2>/dev/null || date +%s | sha256sum | head -c 32)"
    echo "   → Náhodný kľúč vygenerovaný"
fi

# Gateway Token -- voliteľný, auto-generácia
read -rp "🔧 Gateway Token (nechajte prázdne pre auto-generáciu): " GW_TOKEN
if [ -z "$GW_TOKEN" ]; then
    GW_TOKEN="sk-gw-$(openssl rand -hex 16 2>/dev/null || date +%s | sha256sum | head -c 32)"
    echo "   → Náhodný token vygenerovaný"
fi

# --- 5. Uloženie API kľúčov -------------------------------------------
echo ""
echo "📝 Ukladám API kľúče do llm-gateway/.env..."
mkdir -p llm-gateway
cat > llm-gateway/.env <<EOF
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
OPENROUTER_API_KEY=${OPENROUTER_KEY}
DEEPSEEK_API_KEY=${DEEPSEEK_KEY:-}
LITELLM_MASTER_KEY=${LITELLM_KEY}
GATEWAY_TOKEN=${GW_TOKEN}
EOF
chmod 600 llm-gateway/.env
echo "✅ API kľúče uložené (súbor zabezpečený chmod 600)"
echo "   ➜ llm-gateway/.env"

# --- 6. Healthcheck API kľúčov (voliteľné) ----------------------------
echo ""
echo "🔍 Overujem API kľúče (basic formát)..."
ANTHROPIC_PREFIX="${ANTHROPIC_KEY:0:12}"
OPENROUTER_PREFIX="${OPENROUTER_KEY:0:10}"
echo "   ✅ Anthropic: ${ANTHROPIC_PREFIX}..."
echo "   ✅ OpenRouter: ${OPENROUTER_PREFIX}..."
if [ -n "$DEEPSEEK_KEY" ]; then
    DEEPSEEK_PREFIX="${DEEPSEEK_KEY:0:8}"
    echo "   ✅ DeepSeek: ${DEEPSEEK_PREFIX}..."
else
    echo "   ⚠️  DeepSeek: nebol zadaný"
fi

# --- 7. Spustenie LLM Gateway -----------------------------------------
echo ""
echo "🚀 Spúšťam LLM Gateway (docker compose up -d --build)..."
cd llm-gateway

if docker compose version &> /dev/null 2>&1; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi

echo "⏳ Čakám na štart služieb (15 sekúnd)..."
sleep 15

# --- 8. Healthcheck gatewayu ------------------------------------------
echo ""
echo "🔍 Overujem LLM Gateway..."
GATEWAY_OK=false
for i in 1 2 3; do
    if curl -s http://127.0.0.1:4000/healthz > /dev/null 2>&1; then
        GATEWAY_OK=true
        break
    fi
    echo "   (čakám... pokus $i/3)"
    sleep 3
done

if [ "$GATEWAY_OK" = true ]; then
    echo "✅ LLM Gateway beží a odpovedá na porte 4000"
else
    if docker ps | grep -q llm-gateway; then
        echo "⚠️  Kontajnery bežia, ale healthcheck ešte neodpovedá."
        echo "   Skontrolujte neskôr: curl http://127.0.0.1:4000/healthz"
    else
        echo "❌ LLM Gateway sa nespustil. Skontrolujte logy:"
        echo "   cd llm-gateway && docker compose logs"
        exit 1
    fi
fi

# --- 9. Overenie /v1/models endpointu ---------------------------------
echo ""
echo "📋 Overujem zoznam modelov z gatewayu..."
MODEL_COUNT=$(curl -s http://127.0.0.1:4000/v1/models | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    models = [m['id'] for m in d.get('data', [])]
    for m in models:
        print(f'  ✓ {m}')
    print(f'---')
    print(f'Spolu: {len(models)} modelov')
except Exception as e:
    print(f'Chyba: {e}')
" 2>/dev/null || echo "nepodarilo sa načítať modely")
echo "$MODEL_COUNT"

# --- 10. Kopírovanie konfigurácie do ~/.claude -----------------------
cd "$SCRIPT_DIR"

echo ""
echo "📋 Kopírujem konfiguráciu Claude Code..."
mkdir -p "$HOME/.claude"

if [ -f "claude-config/settings.json" ]; then
    cp "claude-config/settings.json" "$HOME/.claude/settings.json"
    echo "✅ settings.json nastavený (predvolený model: claude-free-nemotron-3-super)"
fi

if [ -d "claude-config/projects" ]; then
    mkdir -p "$HOME/.claude/projects"
    cp -r claude-config/projects/* "$HOME/.claude/projects/" 2>/dev/null || true
    echo "✅ Projektové memory dáta skopírované"
fi

# História -- iba ak ešte neexistuje
if [ -f "claude-config/history.jsonl" ] && [ ! -f "$HOME/.claude/history.jsonl" ]; then
    cp "claude-config/history.jsonl" "$HOME/.claude/history.jsonl"
    echo "✅ História konverzácií obnovená"
fi

# --- 11. Nastavenie ~/.bashrc -----------------------------------------
echo ""
echo "📝 Nastavujem premenné prostredia v ~/.bashrc..."

BASHRC="$HOME/.bashrc"
BASHRC_BACKUP="$HOME/.bashrc.claude-backup-$(date +%Y%m%d-%H%M%S)"

# Záloha
cp "$BASHRC" "$BASHRC_BACKUP" 2>/dev/null || true

# Marker bloku -- aby sme nepridávali duplicitne
MARKER_START="# >>> Claude Code LLM Gateway (claude-migration) >>>"
MARKER_END="# <<< Claude Code LLM Gateway (claude-migration) <<<"

# Odstránime starý blok ak existuje
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
fi

cat >> "$BASHRC" << BASHRCEOF

$MARKER_START
# Gateway URL -- smeruje Claude Code na local gateway
export ANTHROPIC_BASE_URL=http://127.0.0.1:4000

# Gateway model discovery -- zobrazí free/DeepSeek modely v /model pickeri
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1

# Gateway token -- router ignoruje, ale Claude Code vyžaduje auth hlavičku
export ANTHROPIC_AUTH_TOKEN=${GW_TOKEN}

# Priame volanie Claude API (obchádza gateway)
claude-direct() {
    env ANTHROPIC_BASE_URL=https://api.anthropic.com \
        ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_KEY}" \
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=0 \
        claude "\$@"
}
$MARKER_END
BASHRCEOF

echo "✅ Premenné nastavené v ~/.bashrc"
echo "   ➜ ANTHROPIC_BASE_URL=http://127.0.0.1:4000"
echo "   ➜ CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1"
echo "   ➜ ANTHROPIC_AUTH_TOKEN=<gateway-token>"
echo "   ➜ claude-direct -- priame volanie Anthropic API (obchádza gateway)"
echo "   📋 Záloha: $BASHRC_BACKUP"

# --- 12. Hotovo --------------------------------------------------------
echo ""
echo "========================================"
echo "  ✅ INŠTALÁCIA DOKONČENÁ!"
echo "========================================"
echo ""
echo "🔄 Aby sa prejavili premenné prostredia, spustite:"
echo "   source ~/.bashrc"
echo "   (alebo otvorte nový terminál)"
echo ""
echo "🤖 Claude Code spustíte príkazom:"
echo "   claude"
echo ""
echo "📌 Prepnúť model v Claude:  /model <názov>"
echo ""
echo "-- DeepSeek V4 (priamo na DeepSeek API) --"
echo "  /model claude-deepseek-v4-flash    DeepSeek V4 Flash"
echo "  /model claude-deepseek-v4-pro      DeepSeek V4 Pro"
echo ""
echo "-- Free modely (cez OpenRouter) --"
echo "  /model claude-free-nemotron-3-ultra    Nemotron 3 Ultra 550B"
echo "  /model claude-free-nemotron-3-super    Nemotron 3 Super 120B ⭐ predvolený"
echo "  /model claude-free-hermes-3-405b       Hermes 3 405B"
echo "  /model claude-free-qwen3-coder         Qwen3 Coder 480B"
echo "  /model claude-free-kimi-k2.6           Kimi K2.6"
echo "  /model claude-free-gemma-4-31b         Gemma 4 31B"
echo "  /model claude-free-llama-3.3-70b       Llama 3.3 70B"
echo "  /model claude-free-glm-4.5-air         GLM 4.5 Air"
echo "  /model claude-free-qwen3-next-80b      Qwen3 Next 80B"
echo "  /model claude-free-gpt-oss-120b        GPT-OSS 120B"
echo ""
echo "-- Platené modely (cez OpenRouter) --"
echo "  /model claude-free-devstral-2           Devstral 2 (paid)"
echo ""
echo "-- Claude modely (priamo na Anthropic API) --"
echo "  (vstavané -- Sonnet/Opus/Haiku, netreba nič prepínať)"
echo ""
echo "-- Priame volanie (bez gateway) --"
echo "  claude-direct    -- použije priamo api.anthropic.com"
echo ""
echo "📊 Správa gatewayu:"
echo "  docker ps | grep llm                 -- stav kontajnerov"
echo "  cd llm-gateway && docker compose logs -f router  -- logy"
echo "  cd llm-gateway && docker compose down            -- zastavenie"
echo ""
echo "========================================"
