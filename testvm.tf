
# External Static IPs
resource "google_compute_address" "static_ips_testvm" {
  count = var.create_test_vm ? 1 : 0
  name     = "${var.prefix}-piptestvm"
  region   = var.region
  depends_on = [ google_compute_network.vpc]
}

# Internal Static IPs
resource "google_compute_address" "internal_ips_testvm" {
  count = var.create_test_vm ? 1 : 0
  name        = "${var.prefix}-internal-iptestvm"
  region      = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnet.name
  depends_on = [ google_compute_network.vpc]
}

resource "google_compute_instance" "testvm" {
    count = var.create_test_vm ? 1 : 0
    name         = "${var.prefix}-testvm"
    machine_type = var.machine_type_dr
    zone         = var.zones[0]

    boot_disk {
        initialize_params {
            image = var.image
            size  = var.disk_size
            type  = var.disk_type
        }
    }

    network_interface {
        network    = google_compute_network.vpc.name
        subnetwork = google_compute_subnetwork.subnet.name
        network_ip = google_compute_address.internal_ips_testvm[0].address
        access_config {
            nat_ip = google_compute_address.static_ips_testvm[0].address
        }
    }

    labels = {
      "environment" = "poc"
      "owner"        = var.owner
      "skip_deletion"   = "yes"
    }
    metadata_startup_script = file("${path.module}/files/test_vm.sh")
}


output "test_vm_details" {
  value = var.create_test_vm ? {
    internal_ip    = google_compute_instance.testvm[0].network_interface[0].network_ip
    external_ip    = google_compute_instance.testvm[0].network_interface[0].access_config[0].nat_ip
    vm_name        = google_compute_instance.testvm[0].name
  } : null

  depends_on = [
    google_compute_instance.testvm
  ]
}