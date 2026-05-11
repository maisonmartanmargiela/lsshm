#!/bin/bash

JSON_FILE="${1:-devices.json}"
USER_FILE="user.json"
SSH_USER="admin"
SSH_PASS=""
SSH_OPTS=(
  -o GSSAPIAuthentication=no
  -o PreferredAuthentications=password,keyboard-interactive
  -o HostKeyAlgorithms=+ssh-rsa
  -o Ciphers=+aes128-cbc,aes256-cbc,3des-cbc
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=5
  -o KexAlgorithms=+diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
)

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
SEL='\033[1;7m'

parse_json() {
  local file="$1"
  local name="" address=""
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ $line =~ \"name\"[[:space:]]*:[[:space:]]*\"(.+)\" ]]; then
      name="${BASH_REMATCH[1]}"
    elif [[ $line =~ \"address\"[[:space:]]*:[[:space:]]*\"(.+)\" ]]; then
      address="${BASH_REMATCH[1]}"
    fi
    if [[ -n "$name" && -n "$address" ]]; then
      printf '%s\t%s\n' "$name" "$address"
      name=""; address=""
    fi
  done < "$file"
}

load_credentials() {
  [[ ! -f "$USER_FILE" ]] && return
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    if [[ $line =~ \"login\"[[:space:]]*:[[:space:]]*\"(.+)\" ]]; then
      SSH_USER="${BASH_REMATCH[1]}"
    elif [[ $line =~ \"password\"[[:space:]]*:[[:space:]]*\"(.+)\" ]]; then
      SSH_PASS="${BASH_REMATCH[1]}"
    fi
  done < "$USER_FILE"
}

load_devices() {
  NAMES=(); IPS=()
  while IFS=$'\t' read -r name ip; do
    NAMES+=("$name")
    IPS+=("$ip")
  done < <(parse_json "$JSON_FILE")
}

filter_devices() {
  local query="${1,,}"
  F_NAMES=(); F_IPS=()
  for i in "${!NAMES[@]}"; do
    local lname="${NAMES[$i],,}"
    if [[ -z "$query" ]] || \
       [[ "$lname" == *"$query"* ]] || \
       [[ "${IPS[$i]}" == *"$query"* ]]; then
      F_NAMES+=("${NAMES[$i]}")
      F_IPS+=("${IPS[$i]}")
    fi
  done
}

draw_menu() {
  local query="$1" cursor="$2" scroll="$3"
  local max_rows=$(( $(tput lines) - 7 ))
  [[ $max_rows -lt 3 ]] && max_rows=3

  tput clear

  echo -e "${B}╔══════════════════════════════════════════════════════════╗${RESET}"
  printf "${B}║${RESET}  ${C}${B}SSH Connect${RESET}  ${DIM}total: ${#NAMES[@]}  │  found: ${#F_NAMES[@]}${RESET}"
  printf '%*s' 31 ''; echo -e "${B}║${RESET}"
  echo -e "${B}╠══════════════════════════════════════════════════════════╣${RESET}"
  printf "${B}║${RESET}  ${Y}Search:${RESET} ${query}▌"
  printf '%*s' $(( 48 - ${#query} )) ''
  echo -e "${B}║${RESET}"
  echo -e "${B}╠══════════════════════════════════════════════════════════╣${RESET}"

  local shown=0
  if [[ ${#F_NAMES[@]} -eq 0 ]]; then
    printf "${B}║${RESET}  ${R}No results found...${RESET}"; printf '%*s' 39 ''; echo -e "${B}║${RESET}"
    shown=1
  else
    local end=$(( scroll + max_rows ))
    [[ $end -gt ${#F_NAMES[@]} ]] && end=${#F_NAMES[@]}
    shown=$(( end - scroll ))
    for (( i=scroll; i<end; i++ )); do
      local name="${F_NAMES[$i]}" ip="${F_IPS[$i]}"
      [[ ${#name} -gt 37 ]] && name="${name:0:34}..."
      if [[ $i -eq $cursor ]]; then
        printf "${B}║${RESET}  ${SEL} ▶ %-37s  %-15s ${RESET}  ${B}║${RESET}\n" "$name" "$ip"
      else
        printf "${B}║${RESET}    ${G}%-37s${RESET}  ${DIM}%-15s${RESET}  ${B}║${RESET}\n" "$name" "$ip"
      fi
    done
  fi

  for (( i=shown; i<max_rows; i++ )); do
    printf "${B}║${RESET}%58s${B}║${RESET}\n" ''
  done

  echo -e "${B}╠══════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${B}║${RESET}  ${DIM}↑↓ navigate  │  Enter connect  │  Esc exit${RESET}          ${B}║${RESET}"
  echo -e "${B}╚══════════════════════════════════════════════════════════╝${RESET}"
}

interactive_menu() {
  local query="" cursor=0 scroll=0

  tput civis
  trap 'tput cnorm; tput clear; exit 0' EXIT INT TERM

  filter_devices ""

  while true; do
    local max_rows=$(( $(tput lines) - 7 ))
    [[ $max_rows -lt 3 ]] && max_rows=3

    draw_menu "$query" "$cursor" "$scroll"

    IFS= read -rsn1 key

    if [[ $key == $'\x1b' ]]; then
      read -rsn1 -t 0.1 k2
      if [[ $k2 == '[' ]]; then
        read -rsn1 -t 0.1 k3
        case $k3 in
          A)
            (( cursor > 0 )) && (( cursor-- ))
            (( cursor < scroll )) && (( scroll-- ))
            ;;
          B)
            (( cursor < ${#F_NAMES[@]} - 1 )) && (( cursor++ ))
            (( cursor >= scroll + max_rows )) && (( scroll++ ))
            ;;
        esac
      else
        tput cnorm; tput clear
        echo -e "${Y}Bye.${RESET}"; exit 0
      fi

    elif [[ $key == $'\x7f' ]] || [[ $key == $'\b' ]]; then
      query="${query%?}"
      cursor=0; scroll=0
      filter_devices "$query"

    elif [[ $key == $'\n' ]] || [[ $key == '' ]]; then
      [[ ${#F_NAMES[@]} -eq 0 ]] && continue
      tput cnorm; tput clear
      connect "${F_NAMES[$cursor]}" "${F_IPS[$cursor]}"
      tput civis
      filter_devices "$query"

    elif [[ $key =~ ^[[:print:]]$ ]]; then
      query+="$key"
      cursor=0; scroll=0
      filter_devices "$query"
    fi
  done
}

connect() {
  local name="$1" ip="$2"

  echo -e "${B}Device:${RESET}  ${G}$name${RESET}"
  echo -e "${B}IP:${RESET}      ${C}$ip${RESET}"
  echo -e "${B}Login:${RESET}   ${C}$SSH_USER${RESET}\n"
  echo -e "${G}Connecting...${RESET}\n"

  if [[ -n "$SSH_PASS" ]] && command -v sshpass &>/dev/null; then
    sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" "${SSH_USER}@${ip}"
  else
    [[ -n "$SSH_PASS" ]] && echo -e "${Y}Tip: install sshpass for automatic password input${RESET}\n"
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${ip}"
  fi

  echo -e "\n${DIM}Connection closed. Press Enter...${RESET}"
  read -r
}

if [[ ! -f "$JSON_FILE" ]]; then
  echo -e "${R}File not found:${RESET} $JSON_FILE"
  echo -e "Usage: ${C}$0 [path/to/devices.json]${RESET}"
  exit 1
fi

load_credentials
load_devices

if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo -e "${R}No devices found in file${RESET}"
  exit 1
fi

interactive_menu
