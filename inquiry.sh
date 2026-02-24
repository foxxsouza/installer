#!/bin/bash
# Coleta interativa de parâmetros (install_primaria)

inquiry_primaria() {
  echo ""
  echo "=========================================="
  echo "  ${APP_DISPLAY_NAME} - Instalação Primária"
  echo "=========================================="
  echo ""
  
  # Nome da instância
  prompt_text INSTANCE_NAME "Nome da instância (ex: post01, cliente1)" "post01"
  INSTANCE_NAME=$(echo "$INSTANCE_NAME" | tr -cd 'a-zA-Z0-9_-' | head -c 30)
  [[ -z "$INSTANCE_NAME" ]] && INSTANCE_NAME="post01"
  DB_NAME="${INSTANCE_NAME}"
  
  # URL do repositório
  if [[ -z "$REPO_URL" ]]; then
    prompt_text REPO_URL "URL do repositório Git" "https://github.com/seu-usuario/automacao.git"
  fi
  prompt_text REPO_BRANCH "Branch do repositório" "main"
  
  # Banco de dados
  prompt_text DB_USER "Usuário PostgreSQL" "postgres"
  prompt_text DB_PASS "Senha do banco de dados" "" 1
  [[ -z "$DB_PASS" ]] && { log_err "Senha obrigatória"; exit 1; }
  prompt_text DB_HOST "Host do PostgreSQL" "localhost"
  prompt_text DB_PORT "Porta do PostgreSQL" "5432"
  
  # Usuário deploy e diretório
  prompt_text DEPLOY_USER "Usuário para rodar a aplicação" "deploy"
  DEPLOY_USER=$(echo "$DEPLOY_USER" | tr -cd 'a-zA-Z0-9_-' | head -c 20)
  [[ -z "$DEPLOY_USER" ]] && DEPLOY_USER="deploy"
  DEPLOY_DIR="/home/${DEPLOY_USER}"
  INST_DIR="${DEPLOY_DIR}/${INSTANCE_NAME}"

  # Portas (faixas: backend 4000-4999, frontend 3000-3999, whatsapp-service 4251)
  echo ""
  echo "  Faixas sugeridas: Backend 4000-4999 | Frontend 3000-3999 | WhatsApp Service 4251"
  prompt_text PORT_BACKEND "Porta do backend" "4250"
  prompt_text PORT_FRONTEND "Porta do frontend (PM2 serve estático)" "3000"
  prompt_text PORT_WA_SERVICE "Porta do WhatsApp Service (Go)" "4251"
  prompt_text REDIS_URI "Redis URI (vazio = sem Redis)" "redis://127.0.0.1:6379"
  
  # Subdomínios (para produção com nginx)
  prompt_text SUBDOMAIN_BACKEND "Subdomínio do backend (ex: api.seudominio.com)" ""
  prompt_text SUBDOMAIN_FRONTEND "Subdomínio do frontend (ex: app.seudominio.com)" ""
  
  # URLs completas
  if [[ -n "$SUBDOMAIN_BACKEND" ]]; then
    BACKEND_URL="https://${SUBDOMAIN_BACKEND}"
    [[ -n "$SUBDOMAIN_FRONTEND" ]] && FRONTEND_URL="https://${SUBDOMAIN_FRONTEND}" || FRONTEND_URL="http://localhost:${PORT_FRONTEND}"
  else
    BACKEND_URL="http://localhost:${PORT_BACKEND}"
    FRONTEND_URL="http://localhost:${PORT_FRONTEND}"
  fi
  FRONTEND_API_URL="${BACKEND_URL}"
  
  # Admin
  prompt_text ADMIN_EMAIL "E-mail do administrador" "admin@admin.com"
  prompt_text ADMIN_PASSWORD "Senha do administrador" "" 1
  [[ -z "$ADMIN_PASSWORD" ]] && ADMIN_PASSWORD="changeme123"
  prompt_text ADMIN_NAME "Nome do administrador" "Administrador"
  
  # Salvar config para install_instancia
  mkdir -p "$PROJECT_ROOT"
  cat > "${PROJECT_ROOT}/config" << CONFIGEOF
INSTANCE_NAME=$INSTANCE_NAME
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
PORT_BACKEND=$PORT_BACKEND
PORT_FRONTEND=$PORT_FRONTEND
PORT_WA_SERVICE=${PORT_WA_SERVICE:-4251}
REDIS_URI=${REDIS_URI:-}
SUBDOMAIN_BACKEND=$SUBDOMAIN_BACKEND
SUBDOMAIN_FRONTEND=$SUBDOMAIN_FRONTEND
BACKEND_URL=$BACKEND_URL
FRONTEND_URL=$FRONTEND_URL
FRONTEND_API_URL=$FRONTEND_API_URL
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_NAME=$ADMIN_NAME
REPO_URL=$REPO_URL
REPO_BRANCH=$REPO_BRANCH
DEPLOY_USER=$DEPLOY_USER
DEPLOY_DIR=$DEPLOY_DIR
INST_DIR=$INST_DIR
CONFIGEOF
  chmod 600 "${PROJECT_ROOT}/config"
  log_ok "Configuração salva em ${PROJECT_ROOT}/config"
}
