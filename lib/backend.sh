#!/bin/bash
# Funções do backend

backend_set_env() {
  local inst_dir="$1"
  local backend_env="${inst_dir}/backend/.env"
  local db_pass_encoded
  db_pass_encoded=$(printf '%s' "$DB_PASS" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" 2>/dev/null) || db_pass_encoded="$DB_PASS"
  
  log_step "Configurando .env do backend..."
  
  cat > "$backend_env" << ENVEOF
NODE_ENV=production
PORT=${PORT_BACKEND}
BACKEND_URL=${BACKEND_URL}
FRONTEND_URL=${FRONTEND_URL}
CORS_ORIGIN=${FRONTEND_URL}

# Banco de dados
DB_DIALECT=postgres
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_NAME=${DB_NAME}
DATABASE_URL=postgresql://${DB_USER}:PLACEHOLDER_PASS@${DB_HOST}:${DB_PORT}/${DB_NAME}?schema=public

# JWT (gerado automaticamente)
JWT_SECRET=$(openssl rand -base64 32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32)

# Admin seed
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_NAME=${ADMIN_NAME}

# Redis (recomendado para filas)
REDIS_URI=${REDIS_URI:-redis://127.0.0.1:6379}

# WhatsApp Service (Go) - URL interna para o backend fazer proxy de sync/campanhas
WA_SERVICE_URL=http://127.0.0.1:${PORT_WA_SERVICE:-4251}

USER_LIMIT=10000
CONNECTIONS_LIMIT=100000
CLOSED_SEND_BY_ME=true
ENVEOF
  sed -i "s|PLACEHOLDER_PASS|${db_pass_encoded}|g" "$backend_env"
  chmod 600 "$backend_env"
  log_ok ".env do backend criado"
}

backend_node_dependencies() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Instalando dependências do backend..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && npm ci 2>/dev/null || npm install --production=false"
  log_ok "Dependências instaladas"
}

backend_node_build() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Compilando backend..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && npx prisma generate && npm run build"
  log_ok "Backend compilado"
}

backend_db_migrate() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Executando migrations..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && npx prisma migrate deploy"
  log_ok "Migrations aplicadas"
}

backend_db_seed() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Criando admin inicial..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && (node dist/scripts/seedAdmin.js 2>/dev/null || (npm run build 2>/dev/null; node dist/scripts/seedAdmin.js))"
  log_ok "Admin criado"
}

backend_start_pm2() {
  local inst_dir="$1"
  local inst_name="$2"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Iniciando backend no PM2 (como $deploy_user)..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && pm2 delete '${inst_name}-backend' 2>/dev/null; true"
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/backend' && pm2 start dist/index.js --name '${inst_name}-backend' && pm2 save"
  log_ok "Backend rodando"
}

# WhatsApp Service (Go - whatsmeow)
wa_service_set_env() {
  local inst_dir="$1"
  local wa_env="${inst_dir}/whatsapp-service/.env"
  local backend_env="${inst_dir}/backend/.env"
  log_step "Configurando .env do whatsapp-service (Go)..."
  mkdir -p "${inst_dir}/whatsapp-service"
  local db_url=""
  local jwt_secret=""
  [[ -f "$backend_env" ]] && db_url=$(grep -E "^DATABASE_URL=" "$backend_env" 2>/dev/null | cut -d= -f2-)
  [[ -f "$backend_env" ]] && jwt_secret=$(grep -E "^JWT_SECRET=" "$backend_env" 2>/dev/null | cut -d= -f2-)
  cat > "$wa_env" << WAENV
DATABASE_URL=${db_url}
JWT_SECRET=${jwt_secret}
WA_SERVICE_PORT=${PORT_WA_SERVICE:-4251}
UPLOADS_PATH=${inst_dir}/backend/uploads
LOG_LEVEL=info
WAENV
  chmod 600 "$wa_env"
  log_ok ".env do whatsapp-service criado"
}

wa_service_build() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  if [[ ! -d "${inst_dir}/whatsapp-service" ]] || [[ ! -f "${inst_dir}/whatsapp-service/go.mod" ]]; then
    log_ok "whatsapp-service não encontrado (opcional)"
    return 0
  fi
  log_step "Compilando whatsapp-service (Go)..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/whatsapp-service' && go build -o whatsapp-service ." || log_warn "Build do whatsapp-service falhou (verifique se Go está instalado)"
  log_ok "whatsapp-service compilado"
}

wa_service_start_pm2() {
  local inst_dir="$1"
  local inst_name="$2"
  local deploy_user="${DEPLOY_USER:-deploy}"
  if [[ ! -x "${inst_dir}/whatsapp-service/whatsapp-service" ]]; then
    log_ok "whatsapp-service binário não encontrado (pulando PM2)"
    return 0
  fi
  log_step "Iniciando whatsapp-service no PM2..."
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/whatsapp-service' && pm2 delete '${inst_name}-wa' 2>/dev/null; true"
  sudo -u "$deploy_user" bash -c "cd '${inst_dir}/whatsapp-service' && pm2 start ./whatsapp-service --name '${inst_name}-wa' && pm2 save"
  log_ok "whatsapp-service rodando"
}
