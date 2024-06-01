module "head" {
  source = "./modules/head"
}

module "worker01" {
  source = "./modules/worker01"
  worker01_vm_count = var.worker01_vm_count
  ok = module.head.ok
}

module "worker02" {
  source = "./modules/worker02"
  worker02_vm_count = var.worker02_vm_count
  ok = module.head.ok
}
