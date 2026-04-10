# Provider Configuration
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      #version = "~> 3.2"
    }
  }
}

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
resource "google_compute_instance" "redis_vms" {
  count        = var.node_count_primary
  name         = "${var.prefix}-vm-${count.index}"
  zone         = var.zones[(count.index) % length(var.zones)]
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
      "${path.module}/scripts/install.sh",
      {
        redis_tar_file_location = var.redis_tar_file_location,
        cluster_admin_username = var.cluster_admin_username,
        cluster_admin_password = var.cluster_admin_password,
        #node_external_ips  = google_compute_address.static_ips[count.index].address,
         # Uncomment the next line if you want to use the existing IPs 
        #node_external_ips  = data.google_compute_address.static_ips[var.external_pips[count.index]].address,
        node_internal_ip = google_compute_address.internal_ips[count.index].address,
        #first_node_internal_ip = google_compute_address.internal_ips[0].address
      }
    )
  }

  # Hostname Configuration
  hostname = "${var.prefix}-${count.index}.${var.cluster_name}"

}


resource "google_compute_instance" "jump_server" {
  #depends_on = [ google_compute_instance.redis_vms ]
  name         = "${var.prefix}-vm-js"
  zone         = var.zones[0 % length(var.zones)]
  machine_type = var.js_machine_type 

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
    #network_ip = google_compute_address.internal_ips[0].address

    # access_config {
    #   nat_ip = google_compute_address.static_ips[0].address
    # }
  }

  labels = {
    "environment" = "poc"
    "owner"        = var.owner
    "skip_deletion"   = "yes"
  }

  # Metadata for Startup Scripts
  metadata = {
    "startup-script" = templatefile(
      "${path.module}/scripts/configure.sh",
      {
        cluster_admin_username = var.cluster_admin_username,
        cluster_admin_password = var.cluster_admin_password,
        no_of_nodes_per_cluster = var.node_count_primary,
        no_of_dr_nodes_per_cluster = var.node_count_dr,
        create_dr_cluster = var.create_dr_cluster,
        cluster_name = var.cluster_name,
        dr_cluster_name = var.cluster_name_dr,
        node_external_ips_joined  = join(" ", google_compute_instance.redis_vms[*].network_interface[0].access_config[0].nat_ip),
         # Uncomment the next line if you want to use the existing IPs 
        #node_external_ips  = join(" ", data.google_compute_address.static_ips[var.external_pips[*]].address),
        node_internal_ips_joined = join(" ", google_compute_instance.redis_vms[*].network_interface[0].network_ip)

        #node_external_ips_joined = join(" ", google_compute_address.static_ips[*].address),
        #node_internal_ips_joined = join(" ", google_compute_address.static_ips[*].address)
        
      }
    )
  }

  # Hostname Configuration
  hostname = "${var.prefix}-js.${var.cluster_name}"

}


# Output VM Details
output "vm_details" {
  value = merge(
    {
      for idx in range(length(google_compute_instance.redis_vms)) :
        idx => {
          internal_ip    = google_compute_instance.redis_vms[idx].network_interface[0].network_ip
          external_ip    = google_compute_instance.redis_vms[idx].network_interface[0].access_config[0].nat_ip
          vm_name        = google_compute_instance.redis_vms[idx].name
        }
    }
  )
}

#  output "node_ips2" {
#    value = google_compute_instance.redis_vms[*].network_interface[0].network_ip
# }

#  output "node_ips3" {
#    value = google_compute_instance.redis_vms[*].network_interface[0].access_config[0].nat_ip
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
