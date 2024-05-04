#!/usr/bin/env bash

# Copyright (c) 2021-2024 ocroguennec
# Author: ocroguennec (ocroguennec)
# License: MIT
# Base on tteck scripts https://github.com/tteck

source $HOME/scripts/env/bash_aliases.env 
BACKUPDIR=$DOCKERDIR/backup

# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
color() {
  YW=$(echo "\033[33m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")
  CL=$(echo "\033[m")
  CM="${GN}✓${CL}"
  CROSS="${RD}✗${CL}"
  BFR="\\r\\033[K"
  HOLD=" "
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# This function handles errors
error_handler() {
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message"
  if [[ "$line_number" -eq 23 ]]; then
    echo -e "The silent function has suppressed the error, run the script with verbose mode enabled, which will provide more detailed output.\n"
  fi
}


# This function displays an informational message with a yellow color.
msg_info() {
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${HOLD} ${BL}${msg}${CL}..."
}

# This function displays a success message with a green color.
msg_ok() {
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}   "
}

# This function displays a error message with a red color.
msg_error() {
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}   "
}

clear
color
catch_errors
Container_name=bitwarden
Directory_name=data
msg_info "Backup $Container_name Container Volumes"
msg_info "Stopping Container"
docker stop $Container_name > /dev/null


Init_Check="yes"
until [[ "$(docker ps -a -q  -f status=exited -f name=${Container_name})" ]] ;
do
  if [[ "$Init_Check" == "yes" ]]; then
    msg="Container $Container_name is still running."
    echo -ne "${BFR} ${HOLD} ${BL}${msg}"
    Init_Check="no"
  else 
    echo -ne "."
  fi  
  sleep 2s
done
msg_ok "$Container_name Container is stopped !"

if [ -d "$BACKUPDIR/$Container_name" ] && [ -n "$(ls -A "$BACKUPDIR/$Container_name")" ]; then
    ls -1dtp "$BACKUPDIR/$Container_name"/* | grep -v '/$' | tail -n +3 | xargs -I {} rm -- {} > /dev/null
else
     mkdir -p "$BACKUPDIR/$Container_name" > /dev/null
fi

docker run --rm --volumes-from $Container_name -v $BACKUPDIR:/backup busybox tar cvfz /backup/$Container_name/$Container_name-$Directory_name-$(date +"%Y%m%d_%H-%M-%S").tar /$Directory_name > /dev/null
msg_ok "Backup $Container_name is done"
msg_info  "Starting Container"
docker start $Container_name > /dev/null

Init_Check="yes"
until [[ "$(docker inspect -f '{{.State.Health.Status}}' "${Container_name}")" != "starting" ]] ;
do
  if [[ "$Init_Check" == "yes" ]]; then
    msg="Container $Container_name is still starting."
    echo -ne "${BFR} ${HOLD} ${BL}${msg}"
    Init_Check="no"
  else 
    echo -ne "."
  fi  
  sleep 2s
done
msg_ok "Backup $Container_name Container Volumes done !"




