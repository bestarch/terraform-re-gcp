variable "prefix" {
  type = string
  description = "prefix for the resources"
  default = "res_tf"
}

variable "owner" {
  type = string
  description = "this should be the name of the person (owner) who is excuting this script"
}

variable "project_id" {
  description = "Google Cloud Project ID"
}

variable "region" {
  description = "Region for resources"
}

variable "zone" {
  description = "Zone for the VMs"
}

variable "zones" {
  type = list(string)
  description = "Zones for the VMs"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
}

variable "tcp_ports" {
  description = "List of TCP ports to allow"
}

variable "udp_ports" {
  description = "List of UDP ports to allow"
}

variable "image" {
  description = "The image to use for the VM instances"
  type        = string
}

variable "create_cluster" {
  description = "Create Redis cluster"
  type        = bool
  default     = true
}

variable "node_count_primary" {
  description = "Size of the primary cluster"
  type        = number
  default     = 3
}

variable "redis_tar_file_location" {
  description = "Redis tar file to download"
  type        = string
}

variable "disk_size" {
  description = "size of boot disk"
  default     = 20
}

variable "machine_type" {
  description = "machine type to use"
  default     = "n4-standard-2"
}

variable "disk_type" {
  description = "Disk type for boot disk"
}

variable "cluster_name" {
  description = "Full name of Redis cluster such as mycluster.example.com"
  type        = string
  default     = "redis-poc.dlqueue.com"
}

variable "cluster_admin_username" {
  description = "username of the cluster admin like admin@example.com"
  type        = string
  default     = "admin@example.com"
}

variable "cluster_admin_password" {
  description = "Password of the cluster admin"
  type        = string
}

variable "create_dr_cluster" {
  description = "Create DR cluster or not. Default is false"
  type        = bool
  default     = false
}

variable "external_pips" {
  description = "List of external IPs for the nodes"
  type        = list(string)
  default     = []
}

variable "cluster_name_dr" {
  description = "Full name of Redis DR cluster such as mycluster-dr.example.com"
  type        = string
}

variable "cluster_admin_username_dr" {
  description = "username of the cluster admin like admin@example.com"
  type        = string
  default     = "admin@example.com"
}

variable "cluster_admin_password_dr" {
  description = "Password of the cluster admin"
  type        = string
}

variable "node_count_dr" {
  description = "Size of the DR cluster"
  type        = number
  default     = 3
}

variable "disk_size_dr" {
  description = "size of boot disk for DR cluster"
  type        = number
  default     = 20
}

variable "machine_type_dr" {
  description = "machine type to use for DR cluster"
  type        = string
  default     = "n4-standard-2"
}

variable "disk_type_dr" {
  description = "Disk type for boot disk for DR cluster"
  type        = string
}

variable "image_dr" {
  description = "The image to use for the VM instances in DR cluster"
  type        = string
}

variable "region_dr" {
  description = "Region for resources in DR cluster"
}

variable "zone_dr" {
  description = "Zone for the VMs in DR cluster"
}

variable "zones_dr" {
  type = list(string)
  description = "Zones for the VMs in DR cluster"
}

variable "subnet_cidr_dr" {
  description = "CIDR range for the subnet in DR cluster"
}

variable "create_test_vm" {
  description = "Create a test VM"
  type        = bool
  default     = false
}

variable "external_pips_dr" {
  description = "List of external IPs for the DR nodes"
  type        = list(string)
  default     = []
}