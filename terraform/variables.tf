# --- vSphere Connection ---
variable "vsphere_user" {
  description = "vSphere/ESXi username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere/ESXi password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vSphere/ESXi server IP or hostname"
  type        = string
}

# --- Infrastructure ---
variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "ha-datacenter"
}

variable "esxi_host" {
  description = "ESXi host IP or hostname"
  type        = string
}

variable "datastore" {
  description = "Datastore name for VM storage"
  type        = string
  default     = "datastore1"
}

variable "network" {
  description = "Network/port group name"
  type        = string
  default     = "VM Network"
}

# --- Network ---
variable "gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS server list"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "subnet_mask" {
  description = "Subnet mask bits"
  type        = number
  default     = 24
}

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "homelab.local"
}

# --- VM IP Addresses ---
variable "k8s_master_ip" {
  description = "K8s master node IP"
  type        = string
}

variable "k8s_worker_1_ip" {
  description = "K8s worker 1 IP"
  type        = string
}

variable "k8s_worker_2_ip" {
  description = "K8s worker 2 IP"
  type        = string
}

variable "ollama_ip" {
  description = "Ollama AI VM IP"
  type        = string
}

variable "database_ip" {
  description = "Database VM IP"
  type        = string
}

variable "devops_ip" {
  description = "DevOps VM IP"
  type        = string
}

variable "monitoring_ip" {
  description = "Monitoring VM IP"
  type        = string
}

variable "productivity_ip" {
  description = "Productivity VM IP"
  type        = string
}
