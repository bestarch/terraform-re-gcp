#!/bin/bash

install() {
  retry_times=$1
  log_info "$logger" "Installing Redis..." 
  sudo yum install wget dnsutils net-tools -y && \
  sudo setenforce 0 && \
  sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config && \
  echo "net.ipv4.ip_local_port_range = 30000 65535" | sudo tee -a /etc/sysctl.conf && \
  #echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf && \
  #sudo mv /etc/resolv.conf /etc/resolv.conf.orig && \
  #sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf && \
  #sudo service systemd-resolved restart && \
  sudo wget -O "/opt/redis_enterprise" "${redis_tar_file_location}" && \
  log_info "$logger" "Successfully downloaded Redis Enterprise Software package" && \
  sudo tar -xvf "/opt/redis_enterprise" -C /opt/ && \
  cd /opt && \
  sudo ./install.sh -y 

  log_info "$logger" "Checking node bootstrap status and address..." 
  log_info "$logger" "curl: https://${first_node_internal_ip}:9443/v1/bootstrap" 
  while true; do
    resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" https://${first_node_internal_ip}:9443/v1/bootstrap)
    log_info "$logger" "Response: $${resp}"
    
    state_idle=$(echo "$${resp}" | jq -e '.bootstrap_status.state == "idle"' 2>/dev/null)
    address_available=$(echo "$${resp}" | jq -e '.local_node_info.available_addresses[] | select(.address == "${first_node_internal_ip}")' 2>/dev/null)

    if [[ "$${state_idle}" == "true" && -n "$${address_available}" ]]; then
      log_info "$logger" "Node bootstrap is completed and address ${first_node_internal_ip} is available."
      break
    else
      log_info "$logger" "Bootstrap state or address not ready. Retrying in $retry_times seconds..."
    fi
    sleep $retry_times
  done

}

create_cluster() {
  log_info "$logger" "Creating Redis cluster..."
  log_info "$logger" "sudo /opt/redislabs/bin/rladmin cluster create addr ${node_internal_ip} \
      external_addr ${node_external_ips} \
      name ${cluster_name} register_dns_suffix \
      username ${cluster_admin_username} password '\"${cluster_admin_password}\"'"

  output=$(sudo /opt/redislabs/bin/rladmin cluster create addr ${node_internal_ip} \
    external_addr ${node_external_ips} \
    name ${cluster_name} register_dns_suffix \
    username ${cluster_admin_username} password ${cluster_admin_password} 2>&1)
  log_info "$logger" "Create cluster output: $output"
}

readonly logger="/redis_install.log"

log_info() {
  local file="$1"
  local message="$2"
  echo "$(date -u +'%Y-%m-%d %H:%M:%S') $message" >> "$file"
}

log_info "$logger" "Redis cluster admin: ${cluster_admin_username}"
log_info "$logger" "Redis cluster password: [REDACTED]"
log_info "$logger" "First node internal IP: ${first_node_internal_ip}"
log_info "$logger" "Node external IPs: ${node_external_ips}"
log_info "$logger" "Redis cluster FQDN: ${cluster_name}"
log_info "$logger" "Create DR cluster: ${create_dr_cluster}"

install 10
create_cluster 