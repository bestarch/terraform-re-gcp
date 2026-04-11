# This Terraform configuration file sets up a Disaster Recovery (DR) cluster on Google Cloud Platform (GCP).

# VPC Configuration
resource "google_compute_network" "vpc_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name                    = "${var.prefix}-vpc-dr"
  auto_create_subnetworks = false
  depends_on = [ google_compute_network.vpc ]
}

# Peering from primary VPC to DR VPC
resource "google_compute_network_peering" "peering_dc_to_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name         = "${var.prefix}-peer-dc-to-dr"
  network      = google_compute_network.vpc.self_link
  peer_network = google_compute_network.vpc_dr[0].self_link
  depends_on = [ google_compute_network.vpc, google_compute_network.vpc_dr ]
}

# Peering from DR VPC to primary VPC
resource "google_compute_network_peering" "peering_dr_to_dc" {
  count = var.create_dr_cluster ? 1 : 0
  name         = "${var.prefix}-peer-dr-to-dc"
  network      = google_compute_network.vpc_dr[0].self_link
  peer_network = google_compute_network.vpc.self_link
  depends_on = [ google_compute_network.vpc, google_compute_network.vpc_dr ]
}


# Subnetwork Configuration
resource "google_compute_subnetwork" "subnet_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name          = "${var.prefix}-subnet-dr"
  network       = google_compute_network.vpc_dr[0].name
  ip_cidr_range = var.subnet_cidr_dr
  region        = var.region_dr
}

# Firewall for TCP Traffic
resource "google_compute_firewall" "tcp_firewall_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name    = "${var.prefix}-tcp-firewall-dr"
  network = google_compute_network.vpc_dr[0].name
  allow {
    protocol = "tcp"
    ports    = var.tcp_ports
  }
  source_ranges = ["0.0.0.0/0"]
}

# Firewall for UDP Traffic
resource "google_compute_firewall" "udp_firewall_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name    = "${var.prefix}-udp-firewall-dr"
  network = google_compute_network.vpc_dr[0].name
  allow {
    protocol = "udp"
    ports    = var.udp_ports
  }
  source_ranges = ["0.0.0.0/0"]
}

# Firewall for ICMP Traffic
resource "google_compute_firewall" "allow_icmp_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name    = "${var.prefix}-icmp-firewall-dr"
  network = google_compute_network.vpc_dr[0].name
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress_dr" {
  count = var.create_dr_cluster ? 1 : 0
  name          = "${var.prefix}-allow-egress-dr"
  network       = google_compute_network.vpc_dr[0].name
  direction     = "EGRESS"
  priority      = 1000
  destination_ranges = ["0.0.0.0/0"]  

  allow {
    protocol = "all"  # Allow all protocols (TCP, UDP, ICMP, etc.)
  }
}

# External Static IPs
resource "google_compute_address" "static_ips_dr" {
  count = var.create_dr_cluster ? var.node_count_dr : 0
  name     = "${var.prefix}-${count.index}-pip-dr"
  region   = var.region_dr
  depends_on = [ google_compute_network.vpc_dr ]
}

## Fetch Existing Static IPs
# Uncomment the next line if you want to use the existing IPs 
# data "google_compute_address" "static_ips_dr" {
#   for_each = toset(var.external_pips_dr)
#   name     = each.value
#   region   = var.region_dr
# }

# Internal Static IPs
resource "google_compute_address" "internal_ips_dr" {
  count = var.create_dr_cluster ? var.node_count_dr : 0
  name        = "${var.prefix}-${count.index}-internal-ip-dr"
  region      = var.region_dr
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnet_dr[0].name
  depends_on = [ google_compute_network.vpc_dr ]
}

# Virtual Machine Instances
resource "google_compute_instance" "vm_instances_dr" {
  count = var.create_dr_cluster ? var.node_count_dr : 0
  name         = "${var.prefix}-vm-dr-${count.index}"
  zone         = var.zones_dr[count.index % length(var.zones_dr)]
  machine_type = var.machine_type_dr 

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = var.image_dr
      size  = var.disk_size_dr
      type  = var.disk_type_dr
    }
  }

  # Network Interfaces
  network_interface {
    network    = google_compute_network.vpc_dr[0].name
    subnetwork = google_compute_subnetwork.subnet_dr[0].name
    network_ip = google_compute_address.internal_ips_dr[count.index].address

    access_config {
      nat_ip = google_compute_address.static_ips_dr[count.index].address
      # Uncomment the next line if you want to use the existing IPs 
      #nat_ip = data.google_compute_address.static_ips_dr[var.external_pips_dr[count.index]].address
    }
  }

  labels = {
    "environment" = "poc"
    "owner"        = var.owner
    "skip_deletion"   = "yes"
  }

  metadata = {
    "startup-script" = templatefile("${path.module}/files/install.sh",
      merge(
        local.install_template_vars, {node_internal_ip = google_compute_address.internal_ips_dr[count.index].address}
      )
    )
  }

  # Hostname Configuration
  hostname = "${var.prefix}-${count.index}.${var.cluster_name_dr}"
}

# Local Variables for IPs and Node Details
# locals {
#   first_node_internal_ip = google_compute_address.internal_ips[0].address
#   node_external_ips = {
#     for idx in range(var.node_count_primary) : idx => google_compute_address.static_ips[idx].address
#   }
# }


# Output VM Details
output "vm_details_dr" {
  value = var.create_dr_cluster ? {
    for idx, instance in google_compute_instance.vm_instances_dr:
      idx => {
        internal_ip    = instance.network_interface[0].network_ip
        external_ip    = instance.network_interface[0].access_config[0].nat_ip
        vm_name        = instance.name
      }
  } : null

  depends_on = [
    google_compute_network.vpc_dr
  ]
}

output "node_ips_dr" {
  value = { for k, v in google_compute_address.static_ips_dr : k => v.address }
  # Uncomment the next line if you want to use the existing IPs 
  #value = { for k, v in data.google_compute_address.static_ips_dr : k => v.address }
}

# Output Redis Cluster login details
output "Redis_cluster_info_dr" {
  value = {
    admin                   = var.cluster_admin_username_dr
    password                = var.cluster_admin_password_dr
  }
}
