# VM module for standalone ESXi (no vCenter)
# VMs are created by govc clone script, then managed here for tracking
resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = var.host_id
  datastore_id     = var.datastore_id
  num_cpus         = var.num_cpus
  memory           = var.memory
  guest_id         = "ubuntu64Guest"
  firmware         = "bios"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0

  network_interface {
    network_id   = var.network_id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "${var.vm_name}-disk"
    size             = var.disk_size
    thin_provisioned = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
