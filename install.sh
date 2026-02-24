#!/bin/bash
# WhatsApp Group Sender SaaS - Instalador GP
# Menu principal: instalação primária, nova instância, trocar domínio, remover
# Uso: sudo ./install.sh

set -e
tput init 2>/dev/null || true

SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do
  PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" 2>/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$PROJECT_ROOT/$SOURCE"
done
PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" 2>/dev/null && pwd )"

# Corrige line endings Windows (CRLF) -> Unix (LF)
for _f in "${PROJECT_ROOT}"/*.sh "${PROJECT_ROOT}"/variables/*.sh "${PROJECT_ROOT}"/lib/*.sh "${PROJECT_ROOT}"/utils/*.sh "${PROJECT_ROOT}"/scripts/*.sh "${PROJECT_ROOT}"/install_primaria "${PROJECT_ROOT}"/install_instancia; do
  [ -f "$_f" ] && sed -i 's/\r$//' "$_f" 2>/dev/null || true
done

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

show_banner() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ██████╗  ██████╗ ${NC}   ${BOLD}WhatsApp Group Sender SaaS - Instalador${NC}               ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ██╔══██╗██╔═══██╗${NC}   Nginx • Certbot • PM2 • PostgreSQL • Node.js         ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ██████╔╝██║   ██║${NC}                                                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ██╔═══╝ ██║   ██║${NC}   ${MAGENTA}[ GP ]${NC} Inserir em meu installer                       ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ██║     ╚██████╔╝${NC}                                                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${GREEN} ╚═╝      ╚═════╝ ${NC}                                                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
}

show_menu() {
  echo -e "${BOLD}  Escolha uma opção:${NC}"
  echo -e ""
  echo -e "  ${GREEN}1)${NC} Instalação primária     - Instalar do zero (Nginx, Certbot, SSL)"
  echo -e "  ${GREEN}2)${NC} Nova instância         - Adicionar outra instância no servidor"
  echo -e "  ${GREEN}3)${NC} Trocar domínio         - Alterar domínios API/App e gerar novo SSL"
  echo -e "  ${GREEN}4)${NC} Remover instalação     - Parar PM2, remover Nginx, opcional: banco/dados"
  echo -e "  ${GREEN}5)${NC} Atualizar              - Puxar alterações do GitHub e recompilar"
  echo -e "  ${GREEN}0)${NC} Sair"
  echo -e ""
}

main() {
  while true; do
    show_banner
    show_menu

    read -p "  Opção [0-5]: " opcao

    case "$opcao" in
      1)
        echo ""
        if [[ -f "${PROJECT_ROOT}/config" ]]; then
          echo -e "${YELLOW}[AVISO]${NC} Já existe uma instalação em ${PROJECT_ROOT}/config"
          read -p "Deseja sobrescrever e reinstalar? (s/N): " resp
          resp="$(echo "$resp" | tr '[:upper:]' '[:lower:]')"
          [[ "$resp" != "s" && "$resp" != "sim" ]] && { echo "Cancelado."; continue; }
        fi
        exec "${PROJECT_ROOT}/install_primaria"
        ;;
      2)
        echo ""
        if [[ ! -f "${PROJECT_ROOT}/config" ]]; then
          echo -e "${RED}[ERRO]${NC} Execute primeiro a instalação primária (opção 1)"
          read -p "Pressione Enter para continuar..." dummy
          continue
        fi
        exec "${PROJECT_ROOT}/install_instancia"
        ;;
      3)
        echo ""
        "${PROJECT_ROOT}/scripts/trocar_dominio.sh"
        read -p "Pressione Enter para voltar ao menu..." dummy
        ;;
      4)
        echo ""
        "${PROJECT_ROOT}/scripts/remover_instalacao.sh"
        read -p "Pressione Enter para voltar ao menu..." dummy
        ;;
      5)
        echo ""
        "${PROJECT_ROOT}/scripts/atualizar.sh"
        read -p "Pressione Enter para voltar ao menu..." dummy
        ;;
      0)
        echo -e "\n${GREEN}Até logo!${NC}\n"
        exit 0
        ;;
      *)
        echo -e "\n${RED}Opção inválida.${NC}\n"
        read -p "Pressione Enter para continuar..." dummy
        ;;
    esac
  done
}

main "$@"
