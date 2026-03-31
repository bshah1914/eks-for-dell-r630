variable "vm_name" {
  type = string
}

variable "num_cpus" {
  type = number
}

variable "memory" {
  type = number
}

variable "disk_size" {
  type = number
}

variable "datastore_id" {
  type = string
}

variable "host_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "ip_address" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "subnet_mask" {
  type = number
}

variable "domain" {
  type = string
}
