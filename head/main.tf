terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "test_vm_storage_pool" {
  name = "head-vm-storage-pool"
  type = "dir"
  # path = "/home/wfuing/test/images"
  path = "/home/wds/zhitai/test/images"
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu24.04-x86-64.qcow2"
  pool = "actor"
  # source = "/home/wfuing/images/ubuntu24.04-x86-64.qcow2"
  source = "/home/wds/zhitai/images/ubuntu24.04-x86-64-n-avx.qcow2"
  format = "qcow2"
}

resource "libvirt_network" "ovs_network" {
  name      = "head-network"
  mode      = "bridge"
  bridge    = "ovsbr1"
  autostart = true
}

resource "libvirt_volume" "vm_disk" {
  name           = "head-actorvm-disk"
  pool           = libvirt_pool.test_vm_storage_pool.name
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "head-commoninit.iso"
  pool           = libvirt_pool.test_vm_storage_pool.name
  network_config = data.template_file.network_config.rendered
  # user_data      = data.template_file.user_data[count.index].rendered
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.yaml")
  vars = {
    ip_address = "192.168.101.10"
    gateway    = "192.168.101.1"
  }
}

resource "libvirt_domain" "vm" {
  name   = "head-vm"
  memory = "4096"
  vcpu   = 2

  network_interface {
    bridge = libvirt_network.ovs_network.bridge
  }

  xml {
    xslt = file("ovs-port.xsl")
  }

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id

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
  depends_on = [libvirt_domain.vm]
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "ubuntu" // 根据你的 VM 配置替换
      password = "123456" // 或使用私钥
      host     = "192.168.101.10"
    }

    inline = [
      "/usr/local/go/bin/go env -w GOPROXY=https://goproxy.cn,direct",
      "cd /home/ubuntu/actor-platform/example && /usr/local/go/bin/go run head/main.go head --addr 192.168.101.10 --port 4968"
    ]
  }
}

