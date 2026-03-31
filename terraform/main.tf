terraform {
  required_version = ">= 1.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}

# ============================================================
# SAFETY: Terraform ONLY manages resources it creates.
# - It will NOT touch, modify, or delete existing VMs
# - It will NOT affect existing networks, datastores, or ISOs
# - "data" blocks are READ-ONLY lookups
# - Only "resource" blocks (inside modules) create new VMs
# - Each new VM has a unique name prefix to avoid conflicts
# - "prevent_destroy" is enabled on all VMs
# - Always run "terraform plan" first to review changes
# ============================================================

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

# --- Data Sources (READ-ONLY) ---
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_host" "host" {
  name          = var.esxi_host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- VM Modules (standalone ESXi - no clone) ---
module "k8s_master" {
  source = "./modules/vm"

  vm_name      = "k8s-master"
  num_cpus     = 2
  memory       = 4096
  disk_size    = 50
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.k8s_master_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "k8s_worker_1" {
  source = "./modules/vm"

  vm_name      = "k8s-worker-1"
  num_cpus     = 4
  memory       = 24576
  disk_size    = 100
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.k8s_worker_1_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "k8s_worker_2" {
  source = "./modules/vm"

  vm_name      = "k8s-worker-2"
  num_cpus     = 4
  memory       = 24576
  disk_size    = 100
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.k8s_worker_2_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "ollama" {
  source = "./modules/vm"

  vm_name      = "ollama-ai"
  num_cpus     = 4
  memory       = 65536
  disk_size    = 300
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.ollama_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "database" {
  source = "./modules/vm"

  vm_name      = "database"
  num_cpus     = 2
  memory       = 16384
  disk_size    = 200
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.database_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "devops" {
  source = "./modules/vm"

  vm_name      = "devops"
  num_cpus     = 2
  memory       = 12288
  disk_size    = 100
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.devops_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "monitoring" {
  source = "./modules/vm"

  vm_name      = "monitoring"
  num_cpus     = 1
  memory       = 4096
  disk_size    = 50
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.monitoring_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}

module "productivity" {
  source = "./modules/vm"

  vm_name      = "productivity"
  num_cpus     = 2
  memory       = 8192
  disk_size    = 100
  datastore_id = data.vsphere_datastore.datastore.id
  host_id      = data.vsphere_resource_pool.pool.id
  network_id   = data.vsphere_network.network.id
  ip_address   = var.productivity_ip
  gateway      = var.gateway
  dns_servers  = var.dns_servers
  subnet_mask  = var.subnet_mask
  domain       = var.domain
}
