# Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Configuration
resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
}

# Subnetwork Configuration
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.prefix}-subnet"
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
}

# Firewall for TCP Traffic
resource "google_compute_firewall" "tcp_firewall" {
  name    = "${var.prefix}-tcp-firewall"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = var.tcp_ports
  }
  source_ranges = ["0.0.0.0/0"]
}

# Firewall for UDP Traffic
resource "google_compute_firewall" "udp_firewall" {
  name    = "${var.prefix}-udp-firewall"
  network = google_compute_network.vpc.name
  allow {
    protocol = "udp"
    ports    = var.udp_ports
  }
  source_ranges = ["0.0.0.0/0"]
}

# Firewall for ICMP Traffic
resource "google_compute_firewall" "allow_icmp" {
  name    = "${var.prefix}-icmp-firewall"
  network = google_compute_network.vpc.name
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress" {
  name          = "${var.prefix}-allow-egress"
  network       = google_compute_network.vpc.name
  direction     = "EGRESS"
  priority      = 1000

  destination_ranges = ["0.0.0.0/0"]  

  allow {
    protocol = "all"  # Allow all protocols (TCP, UDP, ICMP, etc.)
  }
}


# Create public external static IPs
# Uncomment the next line if you want to use already created static IPs
resource "google_compute_address" "static_ips" {
  count = var.node_count_primary
  name     = "${var.prefix}-${count.index}-pip"
  region   = var.region
}

## Fetch Existing Static IPs
# data "google_compute_address" "static_ips" {
#   for_each = toset(var.external_pips)
#   name     = each.value
#   region   = var.region
# }


# Internal Static IPs
resource "google_compute_address" "internal_ips" {
  count = var.node_count_primary
  #for_each    = { for idx in range(var.node_count_primary) : idx => idx }
  name        = "${var.prefix}-${count.index}-internal-ip"
  region      = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnet.name
}

# Virtual Machine Instances
resource "google_compute_instance" "vm_instances" {
  count        = var.node_count_primary
  name         = "${var.prefix}-vm-${count.index}"
  zone         = var.zones[count.index % length(var.zones)]
  machine_type = var.machine_type 

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size
      type  = var.disk_type
    }
  }

  # Network Interfaces
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
    network_ip = google_compute_address.internal_ips[count.index].address

    access_config {
      nat_ip = google_compute_address.static_ips[count.index].address
      # Uncomment the next line if you want to use the existing IPs 
      #nat_ip = data.google_compute_address.static_ips[var.external_pips[count.index]].address
    }
  }

  labels = {
    "environment" = "poc"
    "owner"        = var.owner
    "skip_deletion"   = "yes"
  }

  # Metadata for Startup Scripts
  metadata = {
    "startup-script" = templatefile(
      "${path.module}/${count.index == 0 ? "/scripts/create_cluster.sh" : "/scripts/join_cluster.sh"}",
      {
        redis_tar_file_location = var.redis_tar_file_location,
        cluster_admin_username = var.cluster_admin_username,
        cluster_admin_password = var.cluster_admin_password,
        create_dr_cluster = var.create_dr_cluster,
        cluster_name = var.cluster_name,
        node_external_ips  = google_compute_address.static_ips[count.index].address,
         # Uncomment the next line if you want to use the existing IPs 
        #node_external_ips  = data.google_compute_address.static_ips[var.external_pips[count.index]].address,
        node_internal_ip = google_compute_address.internal_ips[count.index].address,
        first_node_internal_ip = google_compute_address.internal_ips[0].address
      }
    )
  }

  # Hostname Configuration
  hostname = "${var.prefix}-${count.index}.${var.cluster_name}"
}

# Local Variables for IPs and Node Details
# locals {
#   first_node_internal_ip = google_compute_address.internal_ips[0].address
#   node_external_ips = {
#     for idx in range(var.node_count_primary) : idx => google_compute_address.static_ips[idx].address
#   }
# }


# Output VM Details
output "vm_details" {
  value = {
    for idx, instance in google_compute_instance.vm_instances:
      idx => {
        internal_ip    = instance.network_interface[0].network_ip
        external_ip    = instance.network_interface[0].access_config[0].nat_ip
        vm_name        = instance.name
      }
  }
}

# output "node_ips" {
#   value = google_compute_address.static_ips[*].address
  
# }

output "node_ips" {
  value = { for k, v in google_compute_address.static_ips : k => v.address }
   # Uncomment the next line if you want to use the existing IPs 
  #value = { for k, v in data.google_compute_address.static_ips : k => v.address }
}

# Output Redis Cluster login details
output "Redis_cluster_info" {
  value = {
    admin                   = var.cluster_admin_username
    password                = var.cluster_admin_password
  }
}
