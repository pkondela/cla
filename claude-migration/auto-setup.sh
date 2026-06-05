#!/bin/bash

# Auto Setup Script for Claude Migration
# Automatická inštalácia a konfigurácia Claude Code s free modelmi
#
# Použitie:
#   1. Zo zip súboru:  umiestnite auto-setup.sh vedľa claude-migration.zip a spustite
#   2. Z rozbaleného:  spustite priamo ./auto-setup.sh (už sme v claude-migration/)

echo "================================================"
echo "Claude Code Migration - Automatická Inštalácia"
echo "================================================"
echo ""

# Získanie cesty k skriptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Kontrola -- sme už v rozbalenom priečinku, alebo potrebujeme rozbaliť?
if [ -f "install.sh" ] && [ -d "llm-gateway" ]; then
    echo "✅ Už sme v rozbalenom priečinku claude-migration/"
elif [ -f "../claude-migration.zip" ]; then
    # Zip je v rodičovskom priečinku
    echo "📦 Rozbaľujem migration balíček z rodičovského priečinka..."
    cd ..
    unzip -q -o claude-migration.zip
    cd claude-migration
    echo "✅ Balíček úspešne rozbalený"
elif [ -f "claude-migration.zip" ]; then
    # Zip je v aktuálnom priečinku
    echo "📦 Rozbaľujem migration balíček..."
    unzip -q -o claude-migration.zip
    echo "✅ Balíček úspešne rozbalený"
    # Po rozbalení sme buď v claude-migration/ alebo zip bol flat
    if [ -d "claude-migration" ]; then
        cd claude-migration
    fi
else
    echo "❌ Nenašiel sa claude-migration.zip ani install.sh"
    echo "   Umiestnite auto-setup.sh vedľa claude-migration.zip"
    echo "   alebo do rozbaleného priečinka claude-migration/"
    exit 1
fi

# 2. Spustenie inštalácie
echo ""
echo "🚀 Spúšťam inštalačný skript..."
chmod +x install.sh
./install.sh

# 3. Ukončenie
echo ""
echo "================================================"
echo "✅ Hotovo! Všetko je pripravené."
echo ""
echo "Naďalej môžete:"
echo "- Spustiť: claude"
echo "- Skontrolovať: /model"
echo "- Zobraziť dostupné modely: /model"
echo ""
echo "Ak máte akékoľvek problémy, pozrite sa na README.md"
echo "================================================"
