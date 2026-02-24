#!/bin/bash
# Funções de prompt interativo

prompt_text() {
  local var_name="$1"
  local prompt_msg="$2"
  local default="$3"
  local secret="${4:-0}"
  
  if [[ -n "$default" ]]; then
    prompt_msg="${prompt_msg} [$default]"
  fi
  prompt_msg="${prompt_msg}: "
  
  if [[ "$secret" == "1" ]]; then
    read -s -p "$prompt_msg" input
    echo ""
  else
    read -p "$prompt_msg" input
  fi
  
  if [[ -z "$input" && -n "$default" ]]; then
    input="$default"
  fi
  printf -v "$var_name" '%s' "$input"
}

prompt_yesno() {
  local prompt_msg="$1"
  local default="${2:-n}"
  local result="n"
  read -p "${prompt_msg} (s/N): " input
  input="${input:-$default}"
  [[ "$input" == "s" || "$input" == "S" || "$input" == "y" || "$input" == "Y" ]] && result="s"
  echo "$result"
}
