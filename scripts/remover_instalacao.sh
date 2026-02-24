#!/bin/bash
# Remover instalação - PM2, Nginx, opcional: banco e dados
# Uso: sudo ./scripts/remover_instalacao.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $*"; }
log_err()   { echo -e "${RED}[ERRO]${NC} $*"; }

echo ""
echo "=============================================="
echo "  Remover instalação - WhatsApp Group Sender"
echo "=============================================="
echo ""

source "${PROJECT_ROOT}/variables/manifest.sh" 2>/dev/null || true

# Busca config (mesma lógica do atualizar.sh - múltiplos locais + descoberta)
CONFIG_FILE=""
[[ -f "${PROJECT_ROOT}/config" ]] && CONFIG_FILE="${PROJECT_ROOT}/config"
[[ -z "$CONFIG_FILE" ]] && [[ -f "/root/installer/config" ]] && CONFIG_FILE="/root/installer/config"
[[ -z "$CONFIG_FILE" ]] && [[ -f "/root/config" ]] && CONFIG_FILE="/root/config"
search_config_in() {
  local base_dir="$1"
  [[ ! -d "$base_dir" ]] && return 1
  for d in "$base_dir"/*/; do
    [[ -d "$d" ]] || continue
    if [[ -f "${d}installer/config" ]]; then CONFIG_FILE="${d}installer/config"; return 0; fi
    if [[ -f "${d}automacao/installer/config" ]]; then CONFIG_FILE="${d}automacao/installer/config"; return 0; fi
    if [[ -f "${d}config" ]]; then CONFIG_FILE="${d}config"; return 0; fi
  done
  return 1
}
[[ -z "$CONFIG_FILE" ]] && search_config_in /home/deploy || true
[[ -z "$CONFIG_FILE" ]] && search_config_in /var/www || true

# Fallback: descobre instância por backend/.git sem config
discover_instance() {
  local base_dir="$1"
  [[ ! -d "$base_dir" ]] && return 1
  for inst_path in "$base_dir"/*/; do
    [[ -d "$inst_path" ]] || continue
    [[ -d "${inst_path}backend" ]] || continue
    if [[ -d "${inst_path}.git" ]] || [[ -d "${inst_path}backend/.git" ]]; then
      INST_DIR="${inst_path%/}"
      INSTANCE_NAME=$(basename "$INST_DIR")
      DEPLOY_USER="${DEPLOY_USER:-deploy}"
      DB_NAME="${INSTANCE_NAME}"
      CONFIG_FILE="[DISCOVERED]"
      return 0
    fi
  done
  return 1
}
if [[ -z "$CONFIG_FILE" ]]; then
  discover_instance /home/deploy || discover_instance /var/www || true
fi

if [[ -z "$CONFIG_FILE" ]]; then
  log_err "Nenhuma instalação encontrada (config não existe)"
  log_err "Dica: copie o config para installer/config ou em /home/deploy/NOME/installer/config"
  exit 1
fi

if [[ "$CONFIG_FILE" != "[DISCOVERED]" ]]; then
  source "$CONFIG_FILE"
fi
source "${PROJECT_ROOT}/utils/manifest.sh" 2>/dev/null || true

log_info "Instância: $INSTANCE_NAME"
log_info "Deploy: $INST_DIR"
echo ""

read -p "Remover processos PM2 (backend/frontend)? (S/n): " r1
r1="${r1:-s}"
if [[ "$r1" == "s" || "$r1" == "S" ]]; then
  log_info "Parando PM2..."
  sudo -u "${DEPLOY_USER:-deploy}" pm2 delete "${INSTANCE_NAME}-backend" 2>/dev/null || true
  sudo -u "${DEPLOY_USER:-deploy}" pm2 delete "${INSTANCE_NAME}-frontend" 2>/dev/null || true
  sudo -u "${DEPLOY_USER:-deploy}" pm2 save 2>/dev/null || true
  log_ok "PM2 removido"
fi

read -p "Remover configurações Nginx? (S/n): " r2
r2="${r2:-s}"
if [[ "$r2" == "s" || "$r2" == "S" ]]; then
  log_info "Removendo Nginx..."
  sudo rm -f /etc/nginx/sites-enabled/${INSTANCE_NAME}-api 2>/dev/null || true
  sudo rm -f /etc/nginx/sites-enabled/${INSTANCE_NAME}-app 2>/dev/null || true
  sudo rm -f /etc/nginx/sites-available/${INSTANCE_NAME}-api 2>/dev/null || true
  sudo rm -f /etc/nginx/sites-available/${INSTANCE_NAME}-app 2>/dev/null || true
  sudo nginx -t 2>/dev/null && sudo systemctl reload nginx
  log_ok "Nginx removido"
fi

read -p "Remover banco de dados $DB_NAME? (s/N): " r3
r3="${r3:-n}"
if [[ "$r3" == "s" || "$r3" == "S" ]]; then
  log_info "Removendo banco..."
  (cd /tmp && sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null) || true
  log_ok "Banco removido"
fi

read -p "Remover arquivos da instalação ($INST_DIR)? (s/N): " r4
r4="${r4:-n}"
if [[ "$r4" == "s" || "$r4" == "S" ]]; then
  log_info "Removendo arquivos..."
  sudo rm -rf "$INST_DIR"
  log_ok "Arquivos removidos"
fi

echo ""
log_ok "Remoção concluída."
echo ""
