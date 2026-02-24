#!/bin/bash
# Instala dependências do Chrome/Puppeteer para WhatsApp QR code funcionar em produção
# Uso: sudo ./scripts/install_puppeteer_deps.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

source "${PROJECT_ROOT}/variables/manifest.sh"
source "${PROJECT_ROOT}/utils/manifest.sh"
source "${PROJECT_ROOT}/lib/manifest.sh"

echo ""
echo "=============================================="
echo "  Dependências Chrome/Puppeteer (WhatsApp QR)"
echo "=============================================="
echo ""

system_puppeteer_deps_install

echo ""
log_ok "Concluído! Reinicie o backend: pm2 restart NOME-backend"
echo ""
