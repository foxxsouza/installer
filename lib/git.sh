#!/bin/bash
# Clonagem e preparação do repositório

system_git_clone() {
  local inst_dir="$1"
  local repo_url="$2"
  local branch="${3:-main}"
  local deploy_user="${4:-deploy}"
  
  log_step "Clonando repositório em $inst_dir..."
  sudo mkdir -p "$(dirname "$inst_dir")"
  sudo chown -R "${deploy_user}:${deploy_user}" "$(dirname "$inst_dir")"
  
  if [[ -d "$inst_dir" && -d "${inst_dir}/.git" ]]; then
    sudo -u "$deploy_user" bash -c "cd '$inst_dir' && git fetch && git checkout '$branch' && git pull"
    log_ok "Repositório atualizado"
  else
    sudo -u "$deploy_user" git clone -b "$branch" "$repo_url" "$inst_dir"
    log_ok "Repositório clonado"
  fi
}
