#!/bin/bash
# Funções do frontend

frontend_set_env() {
  local inst_dir="$1"
  local frontend_env="${inst_dir}/frontend/config/.env"
  local frontend_env_prod="${inst_dir}/frontend/config/.env.production"
  
  log_step "Configurando variáveis do frontend..."
  mkdir -p "${inst_dir}/frontend/config"
  
  local api_url="${FRONTEND_API_URL:-$BACKEND_URL}"
  [[ "$api_url" != */api ]] && api_url="${api_url}/api"
  cat > "$frontend_env_prod" << EOF
VITE_API_BASE_URL=${api_url}
EOF
  cp "$frontend_env_prod" "$frontend_env"
  log_ok "Variáveis do frontend configuradas"
}

frontend_node_dependencies() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Instalando dependências do frontend..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/frontend' && npm ci 2>/dev/null || npm install"
  log_ok "Dependências instaladas"
}

frontend_node_build() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Compilando frontend..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/frontend' && npm run build"
  [[ -d "${inst_dir}/frontend/dist" ]] && nginx_fix_frontend_permissions "$inst_dir"
  log_ok "Frontend compilado"
}

frontend_start_pm2() {
  local inst_dir="$1"
  local inst_name="$2"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Iniciando frontend no PM2 (como $deploy_user, porta ${PORT_FRONTEND})..."
  which serve &>/dev/null || sudo npm install -g serve
  sudo -u "$deploy_user" bash -c "pm2 delete '${inst_name}-frontend' 2>/dev/null; true"
  sudo -u "$deploy_user" bash -c "pm2 serve '${inst_dir}/frontend/dist' ${PORT_FRONTEND} --spa --name '${inst_name}-frontend' && pm2 save"
  log_ok "Frontend rodando na porta ${PORT_FRONTEND}"
}
