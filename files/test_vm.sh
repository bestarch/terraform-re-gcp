#!/bin/bash

# Install Redis Cli
install() {
  log_info "$logger" "Installing Redis cli..."
  #sudo apt-get update && \
  #sudo apt-get install redis-tools -y && \
  sudo dnf install redis -y && \
  log_info "$logger" "Redis cli installed successfully"
}

readonly logger="/test_vm.log"

log_info() {
  local file="$1"
  local message="$2"
  echo "$(date -u +'%Y-%m-%d %H:%M:%S') ${message}" >> "${file}"
}

install