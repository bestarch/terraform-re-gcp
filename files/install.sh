#!/bin/bash

install() {
  retry_times=$1
  log_info "$logger" "Installing Redis..." 
  sudo yum install wget dnsutils net-tools -y && \
  echo "net.ipv4.ip_local_port_range = 30000 65535" | sudo tee -a /etc/sysctl.conf && \
  sudo wget -O "/opt/redis_enterprise" "${redis_tar_file_location}" && \
  log_info "$logger" "Successfully downloaded Redis Enterprise Software package" && \
  sudo tar -xvf "/opt/redis_enterprise" -C /opt/ && \
  cd /opt && \
  sudo ./install.sh -y 
  sleep 30

  log_info "$logger" "Checking node bootstrap status and address..." 
  log_info "$logger" "curl: https://${node_internal_ip}:9443/v1/bootstrap" 
  while true; do
    resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" https://${node_internal_ip}:9443/v1/bootstrap)
    log_info "$logger" "Response: $${resp}"
    
    state_idle=$(echo "$${resp}" | jq -e '.bootstrap_status.state == "idle"' 2>/dev/null)
    address_available=$(echo "$${resp}" | jq -e '.local_node_info.available_addresses[] | select(.address == "${node_internal_ip}")' 2>/dev/null)

    if [[ "$${state_idle}" == "true" && -n "$${address_available}" ]]; then
      log_info "$logger" "Node bootstrap is completed and address ${node_internal_ip} is available."
      break
    else
      log_info "$logger" "Bootstrap state or address not ready. Retrying in $retry_times seconds..."
    fi
    sleep $retry_times
  done
}

readonly logger="/redis.log"

log_info() {
  local file="$1"
  local message="$2"
  echo "$(date -u +'%Y-%m-%d %H:%M:%S') $message" >> "$file"
}

log_info "$logger" "Redis cluster admin: ${cluster_admin_username}"
log_info "$logger" "Redis cluster password: [REDACTED]"
log_info "$logger" "Master node internal IP: ${node_internal_ip}"
log_info "$logger" "Tar file location: ${redis_tar_file_location}"

install 10