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
  name = "test_vm-storage-pool"
  type = "dir"
  path = "/home/wds/zhitai/test/images"
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu24.04-x86-64.qcow2"
  pool   = "zhitai"
  source = "/home/wds/zhitai/images/ubuntu24.04-x86-64.qcow2"
  format = "qcow2"
}

resource "null_resource" "enable_ip_forwarding" {
  provisioner "local-exec" {
    command = <<EOF
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
EOF
  }
}

# 确保创建桥接和设置桥接 IP 地址的资源在启用 IP 转发之后执行
resource "null_resource" "create_ovs_bridge" {
  depends_on = [null_resource.enable_ip_forwarding]
  provisioner "local-exec" {
    command = <<EOF
if ! sudo ovs-vsctl br-exists ovsbr0; then
  sudo ovs-vsctl add-br ovsbr0
fi
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo ovs-vsctl del-br ovsbr0"
  }
}

resource "null_resource" "setup_bridge_ip" {
  depends_on = [null_resource.create_ovs_bridge]
  provisioner "local-exec" {
    command = "sudo ip addr add 192.168.100.1/24 dev ovsbr0"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo ip addr del 192.168.100.1/24 dev ovsbr0"
  }
}

resource "libvirt_network" "ovs_network" {
  depends_on = [null_resource.create_ovs_bridge, null_resource.setup_bridge_ip, null_resource.enable_ip_forwarding]
  name       = "ovs-network"
  mode       = "bridge"
  bridge     = "ovsbr0"
  addresses  = ["192.168.100.0/24"]
  autostart  = true
}

# resource "libvirt_network" "vm_network" {
#   name      = "vm-network"
#   mode      = "nat"
#   addresses = ["192.168.122.0/24"]
#   # autostart = true
# }

resource "libvirt_volume" "vm_disk" {
  count          = 2
  name           = "vm-disk-${count.index}"
  pool           = libvirt_pool.test_vm_storage_pool.name
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
}

resource "libvirt_domain" "vm" {
  count  = 2
  name   = "vm-${count.index}"
  memory = "4096"
  vcpu   = 2

  network_interface {
    bridge    = libvirt_network.ovs_network.bridge
    addresses = ["192.168.100.${count.index + 50}"]
    # mac    = "52:54:00:00:00:${count.index + 1}"
  }

  # network_interface {
  #   network_id = libvirt_network.vm_network.id
  #   addresses  = ["192.168.122.${count.index + 50}"]
  #   mac        = "52:54:00:01:00:${count.index + 1}"
  # }

  xml {
    xslt = file("ovs-port.xsl")
  }

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  graphics {
    type           = "vnc"
    listen_type    = "none" // 或者 "address"
    listen_address = "127.0.0.1"
    autoport       = true
  }
}
