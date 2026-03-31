output "k8s_master_ip" {
  value = module.k8s_master.vm_ip
}

output "k8s_worker_1_ip" {
  value = module.k8s_worker_1.vm_ip
}

output "k8s_worker_2_ip" {
  value = module.k8s_worker_2.vm_ip
}

output "ollama_ip" {
  value = module.ollama.vm_ip
}

output "database_ip" {
  value = module.database.vm_ip
}

output "devops_ip" {
  value = module.devops.vm_ip
}

output "monitoring_ip" {
  value = module.monitoring.vm_ip
}

output "productivity_ip" {
  value = module.productivity.vm_ip
}
