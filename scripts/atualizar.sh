#!/bin/bash
# Atualizar - puxa alterações do GitHub e recompila
# Uso: sudo ./scripts/atualizar.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

source "${PROJECT_ROOT}/variables/manifest.sh"
source "${PROJECT_ROOT}/utils/manifest.sh"
source "${PROJECT_ROOT}/lib/manifest.sh"

echo ""
echo "=============================================="
echo "  Atualizar - Puxar alterações do GitHub"
echo "=============================================="
echo ""

# Busca config em vários locais (instalação pode ter sido feita de outro diretório)
CONFIG_FILE=""
if [[ -f "${PROJECT_ROOT}/config" ]]; then
  CONFIG_FILE="${PROJECT_ROOT}/config"
elif [[ -f "/root/installer/config" ]]; then
  CONFIG_FILE="/root/installer/config"
elif [[ -f "/root/config" ]]; then
  CONFIG_FILE="/root/config"
fi

if [[ -z "$CONFIG_FILE" ]] && [[ -d /home/deploy ]]; then
  for dir in /home/deploy/*/; do
    [[ -d "$dir" ]] || continue
    if [[ -f "${dir}installer/config" ]]; then
      CONFIG_FILE="${dir}installer/config"
      break
    fi
    if [[ -f "${dir}automacao/installer/config" ]]; then
      CONFIG_FILE="${dir}automacao/installer/config"
      break
    fi
  done
fi

# Fallback: descobre via varredura de /home/deploy
if [[ -z "$CONFIG_FILE" ]] && [[ -d /home/deploy ]]; then
  for inst_path in /home/deploy/*/; do
    [[ -d "$inst_path" ]] || continue
    [[ -d "${inst_path}backend" ]] || continue
    [[ -d "${inst_path}.git" ]] || continue
    INST_DIR="${inst_path%/}"
    INSTANCE_NAME=$(basename "$INST_DIR")
    REPO_URL=$(cd "$INST_DIR" 2>/dev/null && git config --get remote.origin.url 2>/dev/null) || REPO_URL=""
    REPO_BRANCH=$(cd "$INST_DIR" 2>/dev/null && git branch --show-current 2>/dev/null) || REPO_BRANCH="main"
    DEPLOY_USER="deploy"
    DEPLOY_DIR="/home/deploy"
    CONFIG_FILE="[DISCOVERED]"
    break
  done
fi

if [[ -z "$CONFIG_FILE" ]]; then
  log_err "Nenhuma instalação encontrada. Execute primeiro a instalação primária."
  log_err "Dica: copie o config para installer/config ou em /home/deploy/NOME/installer/config"
  exit 1
fi

if [[ "$CONFIG_FILE" != "[DISCOVERED]" ]]; then
  source "$CONFIG_FILE"
fi

if [[ ! -d "$INST_DIR" ]]; then
  log_err "Diretório da instância não encontrado: $INST_DIR"
  exit 1
fi

log_info "Instância: $INSTANCE_NAME"
log_info "Diretório: $INST_DIR"
log_info "Repositório: $REPO_URL (branch: $REPO_BRANCH)"
echo ""

read -p "Atualizar esta instância? (S/n): " r
r="${r:-s}"
[[ "$r" != "s" && "$r" != "S" ]] && { echo "Cancelado."; exit 0; }

# Git pull
log_step "Puxando alterações do GitHub..."
sudo -u "${DEPLOY_USER:-deploy}" bash -c "cd '$INST_DIR' && git fetch origin && git checkout '$REPO_BRANCH' && git pull origin '$REPO_BRANCH'"
log_ok "Código atualizado"

# Backend
log_step "Atualizando backend (deps, prisma, build, migrate)..."
backend_node_dependencies "$INST_DIR"
backend_node_build "$INST_DIR"
backend_db_migrate "$INST_DIR"
log_ok "Backend atualizado"

# Frontend
log_step "Atualizando frontend (deps, build)..."
frontend_node_dependencies "$INST_DIR"
frontend_node_build "$INST_DIR"
log_ok "Frontend atualizado"

# Permissões Nginx (se usar)
if [[ -n "$SUBDOMAIN_FRONTEND" ]] && [[ -d "${INST_DIR}/frontend/dist" ]]; then
  nginx_fix_frontend_permissions "$INST_DIR"
fi

# WhatsApp Service (Go)
if [[ -d "${INST_DIR}/whatsapp-service" ]] && [[ -f "${INST_DIR}/whatsapp-service/go.mod" ]]; then
  log_step "Atualizando whatsapp-service (build, env)..."
  wa_service_set_env "$INST_DIR" 2>/dev/null || true
  wa_service_build "$INST_DIR"
  log_ok "whatsapp-service atualizado"
fi

# Reiniciar PM2
log_step "Reiniciando processos PM2..."
sudo -u "${DEPLOY_USER:-deploy}" pm2 restart "${INSTANCE_NAME}-backend" 2>/dev/null || true
sudo -u "${DEPLOY_USER:-deploy}" pm2 restart "${INSTANCE_NAME}-frontend" 2>/dev/null || true
sudo -u "${DEPLOY_USER:-deploy}" pm2 restart "${INSTANCE_NAME}-wa" 2>/dev/null || true
sudo -u "${DEPLOY_USER:-deploy}" pm2 save 2>/dev/null || true
log_ok "PM2 reiniciado"

echo ""
log_ok "Atualização concluída!"
echo "  Instância: $INSTANCE_NAME"
echo "  Backend:   ${BACKEND_URL}"
echo "  Frontend:  ${FRONTEND_URL}"
echo ""
