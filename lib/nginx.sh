#!/bin/bash
# Configuração Nginx e Certbot

backend_nginx_setup() {
  local inst_name="$1"
  local subdomain="$2"
  local backend_port="$3"
  
  log_step "Configurando Nginx para backend..."
  local cfg="/etc/nginx/sites-available/${inst_name}-api"
  
  sudo tee "$cfg" << NGINXEOF
server {
    listen 80;
    server_name ${subdomain};
    location / {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXEOF
  sudo ln -sf "$cfg" /etc/nginx/sites-enabled/
  log_ok "Nginx backend configurado"
}

# Garante que Nginx (www-data) consiga ler os arquivos estáticos do frontend
# Reconhece instância pelo inst_dir (ex: /home/deploy/instancia/post10)
nginx_fix_frontend_permissions() {
  local inst_dir="$1"
  local deploy_user="${DEPLOY_USER:-deploy}"
  log_step "Ajustando permissões para Nginx ler frontend..."
  [[ -d /home/$deploy_user ]] && sudo chmod 711 /home/$deploy_user
  [[ -d /home/$deploy_user/instancia ]] && sudo chmod 755 /home/$deploy_user/instancia
  [[ -d "$inst_dir" ]] && sudo chmod 755 "$inst_dir" "$inst_dir/frontend" 2>/dev/null || true
  [[ -d "${inst_dir}/frontend/dist" ]] && sudo chmod -R 755 "${inst_dir}/frontend/dist"
  log_ok "Permissões ajustadas (frontend: $inst_dir)"
}

frontend_nginx_setup() {
  local inst_dir="$1"
  local inst_name="$2"
  local subdomain="$3"
  local backend_port="$4"
  local wa_port="${5:-}"
  
  log_step "Configurando Nginx para frontend..."
  local cfg="/etc/nginx/sites-available/${inst_name}-app"
  
  local wa_location=""
  if [[ -n "$wa_port" ]]; then
    wa_location="
    location /api/whatsapp {
        proxy_pass http://127.0.0.1:${wa_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
"
  fi
  
  sudo tee "$cfg" << NGINXEOF
server {
    listen 80;
    server_name ${subdomain};
    root ${inst_dir}/frontend/dist;
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    ${wa_location}
    location /api {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    location /uploads {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_set_header Host \$host;
    }
    location /public {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_set_header Host \$host;
    }
}
NGINXEOF
  sudo ln -sf "$cfg" /etc/nginx/sites-enabled/
  nginx_fix_frontend_permissions "$inst_dir"
  log_ok "Nginx frontend configurado"
}

# Opção: servir frontend via nginx (estático) em vez de PM2
frontend_nginx_static() {
  local inst_dir="$1"
  local inst_name="$2"
  local subdomain="$3"
  local backend_port="${4:-$PORT_BACKEND}"
  
  log_step "Configurando Nginx para frontend (estático)..."
  local cfg="/etc/nginx/sites-available/${inst_name}-app"
  
  sudo tee "$cfg" << NGINXEOF
server {
    listen 80;
    server_name ${subdomain};
    root ${inst_dir}/frontend/dist;
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location /api {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    location /uploads {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_set_header Host \$host;
    }
    location /public {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_set_header Host \$host;
    }
}
NGINXEOF
  sudo ln -sf "$cfg" /etc/nginx/sites-enabled/
  nginx_fix_frontend_permissions "$inst_dir"
  log_ok "Nginx frontend configurado"
}

system_nginx_restart() {
  log_step "Testando e reiniciando Nginx..."
  sudo nginx -t && sudo systemctl reload nginx
  log_ok "Nginx reiniciado"
}

system_certbot_setup() {
  local inst_name="$1"
  local subdomain_api="$2"
  local subdomain_app="${3:-}"
  
  log_step "Configurando SSL com Certbot..."
  cert_args=(--nginx --non-interactive --agree-tos --redirect -m "${ADMIN_EMAIL}")
  [[ -n "$subdomain_api" ]] && cert_args+=(-d "$subdomain_api")
  [[ -n "$subdomain_app" ]] && cert_args+=(-d "$subdomain_app")
  sudo certbot "${cert_args[@]}" 2>/dev/null || log_warn "Certbot não executado (domínios podem não estar apontando ainda)"
  log_ok "SSL configurado"
}
