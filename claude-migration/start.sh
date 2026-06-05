#!/bin/bash
set -e

# ============================================
#  Claude Code + Free/DeepSeek modely - Start
#  Tento skript spúšťa kompletnú inštaláciu.
#  Spúšťajte z rodičovského priečinka (kde je
#  start.sh vedľa claude-migration/), alebo
#  priamo zvnútra claude-migration/.
# ============================================

echo "============================================"
echo "  Claude Code + Free/DeepSeek modely"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Overenie root
if [ "$EUID" -eq 0 ]; then
   echo "❌ Nespúšťajte ako root!"
   exit 1
fi
echo "✅ Používateľ: $USER"

# 2. Spustenie install.sh (ten rieši Node.js, npm, Claude, Docker, API kľúče, .bashrc)
echo ""
echo "🚀 Spúšťam kompletnú inštaláciu..."
chmod +x install.sh
./install.sh
