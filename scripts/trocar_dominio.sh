#!/bin/bash
# Trocar domínio - atualiza Nginx, Certbot SSL e variáveis da aplicação
# Uso: sudo ./scripts/trocar_dominio.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

source "${PROJECT_ROOT}/variables/manifest.sh"
source "${PROJECT_ROOT}/utils/manifest.sh"
source "${PROJECT_ROOT}/lib/manifest.sh"

echo ""
echo "=============================================="
echo "  Trocar domínio - WhatsApp Group Sender"
echo "=============================================="
echo ""

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
      PORT_BACKEND="${PORT_BACKEND:-4250}"
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
  log_err "Nenhuma instalação encontrada. Execute primeiro a instalação primária."
  log_err "Dica: copie o config para installer/config ou em /home/deploy/NOME/installer/config"
  exit 1
fi

if [[ "$CONFIG_FILE" != "[DISCOVERED]" ]]; then
  source "$CONFIG_FILE"
fi

log_info "Domínios atuais:"
echo "  API:  ${SUBDOMAIN_BACKEND:-nenhum}"
echo "  App:  ${SUBDOMAIN_FRONTEND:-nenhum}"
echo ""

if [[ -z "$SUBDOMAIN_BACKEND" && -z "$SUBDOMAIN_FRONTEND" ]]; then
  log_warn "Instalação atual não usa domínios (rodando em localhost)."
  log_info "Digite os novos domínios para configurar Nginx + Certbot:"
fi

prompt_text NEW_SUBDOMAIN_BACKEND "Novo subdomínio API (ex: api.seudominio.com)" "$SUBDOMAIN_BACKEND"
prompt_text NEW_SUBDOMAIN_FRONTEND "Novo subdomínio App (ex: app.seudominio.com)" "$SUBDOMAIN_FRONTEND"

[[ -z "$NEW_SUBDOMAIN_BACKEND" && -z "$NEW_SUBDOMAIN_FRONTEND" ]] && {
  log_err "Informe pelo menos um domínio."
  exit 1
}

# Atualiza config
SUBDOMAIN_BACKEND="$NEW_SUBDOMAIN_BACKEND"
SUBDOMAIN_FRONTEND="$NEW_SUBDOMAIN_FRONTEND"
BACKEND_URL="https://${SUBDOMAIN_BACKEND}"
FRONTEND_URL="https://${SUBDOMAIN_FRONTEND}"
FRONTEND_API_URL="$BACKEND_URL"

# Salva config (usa config da instância quando descoberta)
CONFIG_TO_UPDATE="${CONFIG_FILE}"
[[ "$CONFIG_FILE" == "[DISCOVERED]" ]] && CONFIG_TO_UPDATE="${INST_DIR}/installer/config"
if [[ -f "$CONFIG_TO_UPDATE" ]]; then
  sed -i "s|^SUBDOMAIN_BACKEND=.*|SUBDOMAIN_BACKEND=$SUBDOMAIN_BACKEND|" "$CONFIG_TO_UPDATE"
  sed -i "s|^SUBDOMAIN_FRONTEND=.*|SUBDOMAIN_FRONTEND=$SUBDOMAIN_FRONTEND|" "$CONFIG_TO_UPDATE"
  sed -i "s|^BACKEND_URL=.*|BACKEND_URL=$BACKEND_URL|" "$CONFIG_TO_UPDATE"
  sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=$FRONTEND_URL|" "$CONFIG_TO_UPDATE"
  sed -i "s|^FRONTEND_API_URL=.*|FRONTEND_API_URL=$FRONTEND_API_URL|" "$CONFIG_TO_UPDATE"
elif [[ "$CONFIG_FILE" == "[DISCOVERED]" ]]; then
  mkdir -p "${INST_DIR}/installer"
  CONFIG_TO_UPDATE="${INST_DIR}/installer/config"
  cat > "$CONFIG_TO_UPDATE" << CONFIGSAVE
INSTANCE_NAME=$INSTANCE_NAME
INST_DIR=$INST_DIR
DEPLOY_USER=${DEPLOY_USER:-deploy}
PORT_BACKEND=${PORT_BACKEND:-4250}
SUBDOMAIN_BACKEND=$SUBDOMAIN_BACKEND
SUBDOMAIN_FRONTEND=$SUBDOMAIN_FRONTEND
BACKEND_URL=$BACKEND_URL
FRONTEND_URL=$FRONTEND_URL
FRONTEND_API_URL=$FRONTEND_API_URL
CONFIGSAVE
  chmod 600 "$CONFIG_TO_UPDATE"
  log_info "Config salvo em ${CONFIG_TO_UPDATE}"
fi

# Nginx - recria configs
if [[ -n "$SUBDOMAIN_BACKEND" ]]; then
  backend_nginx_setup "$INSTANCE_NAME" "$SUBDOMAIN_BACKEND" "$PORT_BACKEND"
fi
if [[ -n "$SUBDOMAIN_FRONTEND" ]]; then
  frontend_nginx_setup "$INST_DIR" "$INSTANCE_NAME" "$SUBDOMAIN_FRONTEND" "$PORT_BACKEND"
fi

system_nginx_restart

# Certbot - novo SSL
if [[ -n "$SUBDOMAIN_BACKEND" || -n "$SUBDOMAIN_FRONTEND" ]]; then
  log_step "Gerando certificado SSL com Certbot..."
  CERTBOT_EMAIL="${ADMIN_EMAIL:-admin@localhost}"
  cert_args=(--nginx --non-interactive --agree-tos --redirect -m "$CERTBOT_EMAIL")
  [[ -n "$SUBDOMAIN_BACKEND" ]] && cert_args+=(-d "$SUBDOMAIN_BACKEND")
  [[ -n "$SUBDOMAIN_FRONTEND" ]] && cert_args+=(-d "$SUBDOMAIN_FRONTEND")
  sudo certbot "${cert_args[@]}" 2>/dev/null || log_warn "Certbot: verifique se os domínios apontam para este servidor (DNS)"
fi

# Atualiza .env do backend
if [[ -d "${INST_DIR}/backend" ]]; then
  log_step "Atualizando .env do backend..."
  sed -i "s|^BACKEND_URL=.*|BACKEND_URL=$BACKEND_URL|" "${INST_DIR}/backend/.env"
  sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=$FRONTEND_URL|" "${INST_DIR}/backend/.env"
  sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=$FRONTEND_URL|" "${INST_DIR}/backend/.env"
fi

# Atualiza e rebuild frontend (VITE_API_BASE_URL)
if [[ -d "${INST_DIR}/frontend" ]]; then
  log_step "Atualizando e recompilando frontend..."
  api_url="${BACKEND_URL}"
  [[ "$api_url" != */api ]] && api_url="${api_url}/api"
  echo "VITE_API_BASE_URL=${api_url}" > "${INST_DIR}/frontend/config/.env.production"
  cp "${INST_DIR}/frontend/config/.env.production" "${INST_DIR}/frontend/config/.env" 2>/dev/null || true
  sudo -u "${DEPLOY_USER:-deploy}" bash -c "cd '${INST_DIR}/frontend' && npm run build"
  nginx_fix_frontend_permissions "$INST_DIR"
fi

# Reinicia PM2 frontend se estava rodando
sudo -u "${DEPLOY_USER:-deploy}" pm2 restart "${INSTANCE_NAME}-frontend" 2>/dev/null || true

echo ""
log_ok "Domínio atualizado!"
echo "  API:  $BACKEND_URL"
echo "  App:  $FRONTEND_URL"
echo ""
