#!/bin/bash

# Function to extract current values from terraform.tfvars
get_current_value() {
    local key=$1
    grep -E "^\s*${key}\s*=" terraform.tfvars | sed -E "s|^\s*${key}\s*=\s*\"?([^\"]*)\"?.*|\1|" | awk '{gsub(/"/, ""); print $3}'
}

# Read current values from terraform.tfvars
vpc_name_current=$(get_current_value "vpc_name")
subnet_name_current=$(get_current_value "subnet_name")
firewall_tcp_name_current=$(get_current_value "firewall_tcp_name")
firewall_udp_name_current=$(get_current_value "firewall_udp_name")
firewall_icmp_name_current=$(get_current_value "firewall_icmp_name")
cluster_name_current=$(get_current_value "cluster_name")
prefix_current=$(get_current_value "prefix")
redis_user_current=$(get_current_value "redis_user")
instance_count_current=$(get_current_value "instance_count")
auto_tiering_current=$(get_current_value "auto_tiering")
rdi_current=$(get_current_value "rdi")

# Prompt whether to create or destroy resources
read -p "Enter 'c' to CREATE or 'd' to DESTROY Terraform resources: " action
action=$(echo "$action" | tr '[:upper:]' '[:lower:]') # Convert to lowercase

if [[ "$action" == "d" ]]; then
    echo "Destroying Terraform resources..."
    terraform init
    terraform destroy -auto-approve

    echo "Terraform resources destroyed successfully. Cleaning up Terraform configuration..."
    rm -rf .terraform terraform.tfstate* terraform.tfvars.bak
    echo "Terraform configuration cleaned up."
    exit 0
elif [[ "$action" == "c" ]]; then
    echo -e "\nThis script will enable the creation of the following resources:"
    echo "  - ${instance_count_current} Redis instances with Auto-Tiering: ${auto_tiering_current}."
    echo "  - Redis Data Integration (RDI): ${rdi_current}."
    echo -e "\nIf you would like to configure additional parameters (e.g., instance count, auto-tiering, RDI settings),"
    echo "please edit the 'terraform.tfvars' file directly before proceeding."

    echo -e "\nPress Enter to continue or any other key to cancel..."
    read -n 1 -r action_key
    if [[ "$action_key" != "" ]]; then
        echo -e "\nOperation canceled by user."
        exit 1
    fi
else
    echo "Invalid action. Please enter 'c' to create or 'd' to destroy."
    exit 1
fi

# Prompt the user for input, defaulting to current values if Enter is pressed
read -p "Enter VPC name (current: $vpc_name_current): " vpc_name
vpc_name=${vpc_name:-$vpc_name_current}

read -p "Enter Subnet name (current: $subnet_name_current): " subnet_name
subnet_name=${subnet_name:-$subnet_name_current}

read -p "Enter Firewall TCP name (current: $firewall_tcp_name_current): " firewall_tcp_name
firewall_tcp_name=${firewall_tcp_name:-$firewall_tcp_name_current}

read -p "Enter Firewall UDP name (current: $firewall_udp_name_current): " firewall_udp_name
firewall_udp_name=${firewall_udp_name:-$firewall_udp_name_current}

read -p "Enter Firewall ICMP name (current: $firewall_icmp_name_current): " firewall_icmp_name
firewall_icmp_name=${firewall_icmp_name:-$firewall_icmp_name_current}

read -p "Enter Cluster name (current: $cluster_name_current): " cluster_name
cluster_name=${cluster_name:-$cluster_name_current}

read -p "Enter Prefix for instances (current: $prefix_current): " prefix
prefix=${prefix:-$prefix_current}

read -p "Enter Redis-GCP User for instances (current: $redis_user_current): " redis_user
redis_user=${redis_user:-$redis_user_current}

# Confirm changes with the user
echo -e "\nThe following values will be used in terraform.tfvars:"
echo "VPC Name           : $vpc_name"
echo "Subnet Name        : $subnet_name"
echo "Firewall TCP Name  : $firewall_tcp_name"
echo "Firewall UDP Name  : $firewall_udp_name"
echo "Firewall ICMP Name : $firewall_icmp_name"
echo "Cluster Name       : $cluster_name"
echo "VM Name Prefix     : $prefix"
echo "Redis User         : $redis_user"

read -p "Do you want to proceed with these changes? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Operation aborted."
    exit 1
fi

# Update specific variables in terraform.tfvars
sed -i.bak \
    -e "s|^vpc_name *=.*|vpc_name            = \"$vpc_name\"|" \
    -e "s|^subnet_name *=.*|subnet_name         = \"$subnet_name\"|" \
    -e "s|^firewall_tcp_name *=.*|firewall_tcp_name   = \"$firewall_tcp_name\"|" \
    -e "s|^firewall_udp_name *=.*|firewall_udp_name   = \"$firewall_udp_name\"|" \
    -e "s|^firewall_icmp_name *=.*|firewall_icmp_name  = \"$firewall_icmp_name\"|" \
    -e "s|^cluster_name *=.*|cluster_name        = \"$cluster_name\"|" \
    -e "s|^prefix *=.*|prefix              = \"$prefix\"|" \
    -e "s|^redis_user *=.*|redis_user          = \"$redis_user\"|" \
    terraform.tfvars

echo "Updated terraform.tfvars:"
cat terraform.tfvars

# Initialize Terraform and apply the configuration
echo "Initializing Terraform..."
terraform init

echo "Applying Terraform changes..."
# terraform apply -auto-approve

echo "Terraform resources created successfully."
