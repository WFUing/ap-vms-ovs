terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
    openvswitch = {
      source  = "i2ec.top/local/openvswitch"
      version = "1.0.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "openvswitch" {}

resource "openvswitch_bridge" "ovsbr0" {
  name       = "ovsbr0"
  ip_address = "192.168.100.1/24"
}

resource "libvirt_pool" "test_vm_storage_pool" {
  name = "worker01-vm-storage-pool"
  type = "dir"
  # path = "/home/wfuing/test/images"
  path = "/home/wds/zhitai/test/images1"
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu24.04-x86-64.qcow2"
  pool = "actor"
  # source = "/home/wfuing/images/ubuntu24.04-x86-64.qcow2"
  source = "/home/wds/zhitai/images/ubuntu24.04-x86-64-n-avx.qcow2"
  format = "qcow2"
}

resource "libvirt_network" "ovs_network" {
  depends_on = [openvswitch_bridge.ovsbr0]
  name       = "worker01-network"
  mode       = "bridge"
  bridge     = "ovsbr0"
  # addresses = ["192.168.100.0/24"]
  autostart = true
}

resource "libvirt_volume" "vm_disk" {
  count          = var.worker01_vm_count
  name           = "vm-disk-${count.index}"
  pool           = libvirt_pool.test_vm_storage_pool.name
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
}

resource "libvirt_cloudinit_disk" "commoninit" {
  count          = var.worker01_vm_count
  name           = "worker01-commoninit-${count.index}.iso"
  pool           = libvirt_pool.test_vm_storage_pool.name
  network_config = data.template_file.network_config[count.index].rendered
  # user_data      = data.template_file.user_data[count.index].rendered
}

data "template_file" "network_config" {
  count    = var.worker01_vm_count
  template = file("${path.root}/network_config.yaml")
  vars = {
    ip_address = "192.168.100.${count.index + 10}"
    gateway    = "192.168.100.1"
  }
}

resource "libvirt_domain" "vm" {
  count  = var.worker01_vm_count
  name   = "worker01-vm-${count.index}"
  memory = "4096"
  vcpu   = 2

  network_interface {
    bridge = libvirt_network.ovs_network.bridge
  }

  xml {
    xslt = file("ovs-port.xsl")
  }

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  graphics {
    type           = "vnc"
    listen_type    = "none" // 或者 "address"
    listen_address = "127.0.0.1"
    autoport       = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

}

resource "null_resource" "activate_actor" {
  count      = var.worker01_vm_count
  depends_on = [var.ok, libvirt_domain.vm]
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "ubuntu" // 根据你的 VM 配置替换
      password = "123456" // 或使用私钥
      host     = "192.168.100.${count.index + 10}"
    }

    inline = [
      "/usr/local/go/bin/go env -w GOPROXY=https://goproxy.cn,direct",
      "cd /home/ubuntu/actor-platform/example && /usr/local/go/bin/go run worker/main.go worker --addr 192.168.100.${count.index + 10} --remote_addr 192.168.101.10 --remote_port 4968"
    ]
  }
}

