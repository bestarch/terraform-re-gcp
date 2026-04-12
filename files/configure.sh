#!/bin/bash

join() {
  retry_times=$1
  # node_internal_ips=($2)
  # node_external_ips=($3)
  IFS=' ' read -r -a node_internal_ips <<< "$2"
  IFS=' ' read -r -a node_external_ips <<< "$3"

  log_info "$logger" "Waiting for Master node to create Redis Cluster..."
  node_count=$4
  for ((i=1; i<node_count; i++)); do
     log_info "$logger" "Master node internal IP: $${node_internal_ips[0]}"
     log_info "$logger" "Joining cluster with Master node internal IP: $${node_internal_ips[0]} and external IP: $${node_external_ips[0]}"
     while true; do
        resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" "https://$${node_internal_ips[0]}:9443/v1/cluster/check")
        log_info "$logger" "Response: '$resp'"

        if [[ -z "$resp" ]]; then
          log_info "$logger" "Empty response from cluster check API. Retrying..."
          sleep $retry_times
          continue
        fi

        # if echo "$resp" | jq -e --argjson no_of_nodes "$i" '(.cluster_test_result == true) and (.nodes != null) and ((.nodes | length) == $no_of_nodes) and (all(.nodes[]?; .result == true))' >/dev/null 2>&1; then
        if echo "$resp" | jq -e '.cluster_test_result == true' >/dev/null 2>&1; then
  
          # Join cluster command is commented to avoid joining cluster using rladmin. Please uncomment and use when needed.
          # echo "Cluster is active and all nodes are healthy!"
          # log_info "$logger" "Joining cluster..."
          # log_info "$logger" "sudo /opt/redislabs/bin/rladmin cluster join nodes $${node_internal_ips[0]} \
          #       external_addr $${node_external_ips[$i]} \
          #       username ${cluster_admin_username} password ${cluster_admin_password}"

          # output=$(sudo /opt/redislabs/bin/rladmin cluster join nodes $${node_internal_ips[0]} \
          #       external_addr $${node_external_ips[$i]} \
          #       username ${cluster_admin_username} password ${cluster_admin_password} 2>&1)
          # log_info "$logger" "Join cluster output: $output"
          # if echo "$output" | grep -q "ok"; then
          #   log_info "$logger" "$${node_internal_ips[$i]} successfully joined the cluster."
          #   break
          # else
          #   log_info "$logger" "$${node_internal_ips[$i]} failed to join the cluster. Retrying in $retry_times seconds..."
          #   sleep $retry_times
          #   continue
          # fi

          log_info "$logger" "curl -s -k -u ${cluster_admin_username}:${cluster_admin_password} \
            -H \"Content-Type: application/json\" \
            -H \"Accept: application/json\" \
            -X POST https://$${node_internal_ips[$i]}:9443/v1/bootstrap/join_cluster \
            -d '{\"action\": \"join_cluster\", \"cluster\": {\"nodes\": [\"$${node_internal_ips[0]}\"]}, \"node\": {\"identity\": {\"addr\": \"$${node_internal_ips[$i]}\", \"external_addr\": [\"$${node_external_ips[$i]}\"]}}, \"credentials\": {\"username\": \"${cluster_admin_username}\", \"password\": \"${cluster_admin_password}\"}}'"  
          
          join_response=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -X POST "https://$${node_internal_ips[$i]}:9443/v1/bootstrap/join_cluster" \
            -d '{"action":"join_cluster","cluster":{"nodes":["'"$${node_internal_ips[0]}"'"]},"node":{"identity":{"addr":"'"$${node_internal_ips[$i]}"'","external_addr":["'"$${node_external_ips[$i]}"'"]}},"credentials":{"username":"'"${cluster_admin_username}"'","password":"'"${cluster_admin_password}"'"}}')

          log_info "$logger" "Join cluster response: $join_response"

          error_code=$(echo "$join_response" | jq -r '.error_code' 2>/dev/null)
          if [[ -z "$error_code" ]]; then
            log_info "$logger" "Node joined the cluster successfully"
            sleep 30 # Sleep to allow cluster to stabilize before next node joins
            break
          else
            log_info "$logger" "Failed to join cluster. error_code: $error_code"
            log_info "$logger" "$${node_internal_ips[$i]} failed to join the cluster. Retrying in $retry_times seconds..."
             sleep $retry_times
             continue
          fi

        else
          log_info "$logger" "Master node is not ready or not all nodes are healthy. Retrying in $retry_times seconds..."
          sleep $retry_times
        fi
       
     done
  done

}

create() {
  local node_internal_ip=$1
  local node_external_ip=$2

  log_info "$logger" "Checking node bootstrap status and address..." 
  log_info "$logger" "curl: https://$${node_internal_ip}:9443/v1/bootstrap" 
  log_info "Invoking to check bootstrap status --> curl -s -k -u ${cluster_admin_username}:${cluster_admin_password} https://$${node_internal_ip}:9443/v1/bootstrap"
  while true; do
    resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" https://$${node_internal_ip}:9443/v1/bootstrap)
    log_info "$logger" "Response: $${resp}"
    
    state_idle=$(echo "$${resp}" | jq -e '.bootstrap_status.state == "idle"' 2>/dev/null)
    address_available=$(echo "$${resp}" | jq -e --arg node_internal_ip "$${node_internal_ip}" '.local_node_info.available_addresses[] | select(.address == $node_internal_ip)' 2>/dev/null)

    if [[ "$${state_idle}" == "true" && -n "$${address_available}" ]]; then
      log_info "$logger" "Node bootstrap is completed and $${node_internal_ip} is available."
      break
    else
      log_info "$logger" "Bootstrap state or machine not ready. Retrying in 5 seconds..."
    fi
    sleep 5
  done

  # Create cluster command is commented to avoid cluster creation using rladmin. Please uncomment and use when needed.
  # log_info "$logger" "sudo /opt/redislabs/bin/rladmin cluster create addr $${node_internal_ip} \
  #     external_addr $${node_external_ip} \
  #     name ${cluster_name} register_dns_suffix \
  #     username ${cluster_admin_username} password '\"${cluster_admin_password}\"'"

  # output=$(sudo /opt/redislabs/bin/rladmin cluster create addr $${node_internal_ip} \
  #   external_addr $${node_external_ip} \
  #   name ${cluster_name} register_dns_suffix \
  #   username ${cluster_admin_username} password ${cluster_admin_password} 2>&1)
  # log_info "$logger" "Create cluster output: $output"

  log_info "$logger" "Creating Redis cluster using REST API..."
  log_info "$logger" "curl -s -k -u ${cluster_admin_username}:${cluster_admin_password} \
  -H \"Content-Type: application/json\" \
  -H \"Accept: application/json\" \
  -X POST https://$${node_internal_ip}:9443/v1/bootstrap/create_cluster \
  -d '{\"action\": \"create_cluster\", \"cluster\": {\"nodes\": [], \"name\": \"${cluster_name}\"}, \"node\": {\"identity\": {\"addr\": \"$${node_internal_ip}\", \"external_addr\": [\"$${node_external_ip}\"]}}, \"credentials\": {\"username\": \"${cluster_admin_username}\", \"password\": \"${cluster_admin_password}\"}}'" 
  
  resp=$(curl -s -k -u "${cluster_admin_username}:${cluster_admin_password}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST "https://$${node_internal_ip}:9443/v1/bootstrap/create_cluster" \
  -d '{"action":"create_cluster","cluster":{"nodes":[],"name":"'"${cluster_name}"'"},"node":{"identity":{"addr":"'"$${node_internal_ip}"'","external_addr":["'"$${node_external_ip}"'"]}},"credentials":{"username":"'"${cluster_admin_username}"'","password":"'"${cluster_admin_password}"'"}}')
  
  log_info "$logger" "Create cluster response: $resp"

  error_code=$(echo "$resp" | jq -r '.error_code' 2>/dev/null)
  if [[ -z "$error_code" ]]; then
    log_info "$logger" "Cluster created successfully"
    sleep 30 # Sleep to allow cluster to stabilize before other node joins
    return 0
  else
    log_info "$logger" "Cluster creation failed. error_code: $error_code"
    exit 1
  fi
}

readonly logger="/redis.log"

log_info() {
  local file="$1"
  local message="$2"
  echo "$(date -u +'%Y-%m-%d %H:%M:%S') $message" >> "$file"
}

node_external_ips="${node_external_ips_joined}"
node_internal_ips="${node_internal_ips_joined}"

IFS=' ' read -r -a node_internal_ips <<< "$node_internal_ips"
IFS=' ' read -r -a node_external_ips <<< "$node_external_ips"

node_external_ips_dr="${node_external_ips_joined_dr}"
node_internal_ips_dr="${node_internal_ips_joined_dr}"

IFS=' ' read -r -a node_internal_ips_dr <<< "$node_internal_ips_dr"
IFS=' ' read -r -a node_external_ips_dr <<< "$node_external_ips_dr"

log_info "$logger" "Redis cluster admin credentials: ${cluster_admin_username}:${cluster_admin_password}"
log_info "$logger" "Redis cluster primary FQDN: ${cluster_name}"
log_info "$logger" "Create DR cluster: ${create_dr_cluster}"
log_info "$logger" "Internal IP addresses: ${node_internal_ips_joined}"
log_info "$logger" "External IP addresses: ${node_external_ips_joined}"

log_info "$logger" "Internal IP Count: $${#node_internal_ips[@]}"
log_info "$logger" "External IP Count: $${#node_external_ips[@]}"

log_info "$logger" "Primary cluster node count: ${no_of_nodes_per_cluster}"


configure_cluster() {

  log_info "$logger" "Proceeding with primary cluster creation."

  if [ "${no_of_nodes_per_cluster}" -gt 1 ]; then
    log_info "$logger" "Multiple nodes per cluster requested."
    create $${node_internal_ips[0]} $${node_external_ips[0]}
    if [[ $? -eq 0 ]]; then
      log_info "$logger" "Cluster creation succeeded. Proceeding to join nodes."
      join 10 "$${node_internal_ips[*]}" "$${node_external_ips[*]}" "${no_of_nodes_per_cluster}"
    else
      log_info "$logger" "Cluster creation failed. Aborting join operation."
      exit 1
    fi
  else
    log_info "$logger" "Single node cluster requested. Creating cluster with single node."
    create $${node_internal_ips[0]} $${node_external_ips[0]}
    if [[ $? -eq 0 ]]; then
      log_info "$logger" "Single node cluster created successfully."
    else
      log_info "$logger" "Single node cluster creation failed."
      exit 1
    fi
  fi

  if [ "${create_dr_cluster}" = "true" ]; then
      log_info "$logger" "DR Cluster creation requested. DR Cluster FQDN: ${dr_cluster_name}"
      log_info "$logger" "DR cluster node count: ${no_of_dr_nodes_per_cluster}"
      log_info "$logger" "Redis DR cluster FQDN: ${dr_cluster_name}"

      if [ "${no_of_dr_nodes_per_cluster}" -gt 1 ]; then
        log_info "$logger" "Multiple nodes per cluster requested."
        create $${node_internal_ips_dr[0]} $${node_external_ips_dr[0]}
        if [[ $? -eq 0 ]]; then
          log_info "$logger" "Cluster creation succeeded. Proceeding to join nodes."
          join 10 "$${node_internal_ips_dr[*]}" "$${node_external_ips_dr[*]}" "${no_of_dr_nodes_per_cluster}"
        else
          log_info "$logger" "Cluster creation failed. Aborting join operation."
          exit 1
        fi
      else
        log_info "$logger" "Single node cluster requested. Creating cluster with single node."
        create $${node_internal_ips_dr[0]} $${node_external_ips_dr[0]}
        if [[ $? -eq 0 ]]; then
          log_info "$logger" "Single node cluster created successfully."
        else
          log_info "$logger" "Single node cluster creation failed."
          exit 1
        fi
      fi

  fi
}

configure_cluster