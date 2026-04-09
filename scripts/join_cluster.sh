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
  sudo tar -xvf "/opt/redis_enterprise" -C /opt/ && \
  cd /opt && \
  sudo ./install.sh -y 

  log_info "$logger" "Checking node bootstrap status and address..." 
  log_info "$logger" "Curl: https://${first_node_internal_ip}:9443/v1/bootstrap"
  while true; do
    resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" https://${first_node_internal_ip}:9443/v1/bootstrap)
    log_info "$logger" "Response: $${resp}"

    state_completed=$(echo "$${resp}" | jq -e '.bootstrap_status.state == "completed"' 2>/dev/null)
    address_present=$(echo "$${resp}" | jq -e '.local_node_info.available_addresses[] | select(.address == "${first_node_internal_ip}")' 2>/dev/null)

    if [[ "$${state_completed}" == "true" && -n "$${address_present}" ]]; then
      log_info "$logger" "Node bootstrap is completed and address ${first_node_internal_ip} is available."
      break
    else
      log_info "$logger" "Bootstrap state or address not ready. Retrying in $retry_times seconds..."
    fi
    sleep $retry_times
  done
}


join_cluster() {
  retry_times=$1
  log_info "$logger" "Waiting for Master node to create Redis Cluster..."
  while true; do
    resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" "https://${first_node_internal_ip}:9443/v1/cluster/check")
    log_info "$logger" "Response: $resp"

    if echo "$resp" | jq -e '.cluster_test_result == true and .nodes[0].node_uid == 1 and .nodes[0].result == true' > /dev/null 2>&1; then
      log_info "$logger" "Joining cluster..."
      log_info "$logger" "sudo /opt/redislabs/bin/rladmin cluster join nodes ${first_node_internal_ip} \
            external_addr ${node_external_ips} \
            username ${cluster_admin_username} password ${cluster_admin_password}"

      output=$(sudo /opt/redislabs/bin/rladmin cluster join nodes ${first_node_internal_ip} \
            external_addr ${node_external_ips} \
            username ${cluster_admin_username} password ${cluster_admin_password} 2>&1)
      log_info "$logger" "Join cluster output: $output"
      if echo "$output" | grep -q "ok"; then
        log_info "$logger" "Successfully joined the cluster."
        break
      else
        log_info "$logger" "Failed to join the cluster. Retrying in $retry_times seconds..."
        sleep $retry_times
        continue
      fi
    else
      log_info "$logger" "Master node is not ready. Retrying in $retry_times seconds..."
    fi
  done
}

readonly logger="/redis_install.log"

log_info() {
  local file="$1"
  local message="$2"
  echo "$(date -u +'%Y-%m-%d %H:%M:%S') $message" >> "$file"
}

log_info "$logger" "Redis Cluster Admin: ${cluster_admin_username}"
log_info "$logger" "Redis Cluster Password: ${cluster_admin_password}"
log_info "$logger" "First Node Internal IP: ${first_node_internal_ip}"
log_info "$logger" "Node External IPs: ${node_external_ips}"
log_info "$logger" "Redis Cluster FQDN: ${cluster_name}"
log_info "$logger" "Create DR cluster : ${create_dr_cluster}"

install 10
join_cluster 10