
![](img/apvm.png)

open-vswitch 的 provider 在 https://github.com/WFUing/terraform-provider-openvswitch

## 准备vm

- 安装qemu和libvirt、virt-manager，
- 准备ubuntu镜像，图形化安装即可

## 配置环境

**安装Go环境**

有两种方法 

- Go 官网推荐的方法
    - `rm -rf /usr/local/go && curl -OL https://golang.org/dl/go1.22.2.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz`
    - `sudo vim $HOME/.profile` ，添加 `export PATH=$PATH:/usr/local/go/bin`
    - `source $HOME/.profile`
- APT 安装
    - `sudo apt install golang-go`，可以直接安装，安装的cache在`/var/lib/apt`，项目目录在`/usr/local`，具体没有考证过，已使用第一种方法安装了

`go version`

**安装 nodejs**

install volta

```sh
# install Volta
curl https://get.volta.sh | bash

# install Node
volta install node

# start using Node
node
```

install node

```sh
volta install node
```

**配置protobuf**

```sh
sudo apt-get install pkg-config libczmq-dev
cd proto
npm install
bash protobuf-gen.sh
```

**配置libtensorflow**

```sh
# run with root privileges
curl -L https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.15.0.tar.gz | sudo tar xz --directory /usr/local
ldconfig
```

**配置gocv**

- https://github.com/hybridgroup/gocv
- https://docs.opencv.org/4.x/d7/d9f/tutorial_linux_install.html

```sh
git clone https://github.com/hybridgroup/gocv.git

cd gocv
make install

cd /usr/local/go/src/gocv.io/x/gocv
go run ./cmd/version/main.go
```

输出

```sh
gocv version: 0.36.1
opencv lib version: 4.8.0
```

## 配置虚拟webcam

在 Ubuntu 上创建一个虚拟的 webcam 可以通过多种方式实现，但一个比较流行的方法是使用 v4l2loopback 模块，这是一个能够创建虚拟视频设备的 Linux 内核模块。这样的虚拟设备可以用于测试、视频录制、直播或作为真实 webcam 的替代。以下是如何在 Ubuntu 上安装和配置 v4l2loopback 来创建虚拟 webcam 的步骤：

```sh
sudo apt-get update
sudo apt-get install v4l2loopback-dkms
```

创建设备

```sh
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual Webcam" exclusive_caps=1
```

以图片作为输入

```sh
ffmpeg -loop 1 -re -i /media/wds/zhitai/images.jpeg -f v4l2 -vcodec rawvideo -pix_fmt yuv420p /dev/video10
```

验证webcam输出

```sh
ffplay /dev/video10
# 或
fswebcam -d /dev/video0 output.jpg
```

**设置开机启动服务**

*配置 v4l2loopback 模块自动加载*

创建模块配置文件

```sh
sudo vim /etc/modules-load.d/v4l2loopback.conf
```

添加模块加载指令，在打开的文件中输入以下内容

```
v4l2loopback
```

设置模块参数

```sh
sudo vim /etc/modprobe.d/v4l2loopback-options.conf
```

在文件中添加以下内容来指定你的参数

```
options v4l2loopback devices=1 video_nr=10 card_label="Virtual Webcam" exclusive_caps=1
```

**创建一个 systemd 服务来播放视频**

创建一个新的 systemd 服务文件

```sh
sudo vim /etc/systemd/system/virtual-webcam.service
```

编辑并保存服务文件，在服务文件中添加以下内容

```
[Unit]
Description=Start Virtual Webcam
After=network.target

[Service]
ExecStart=/usr/bin/ffmpeg -stream_loop -1 -re -i /home/ubuntu/video.mp4 -map 0:v -vcodec mjpeg -q:v 2 -f v4l2 /dev/video10
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- `-vcodec mjpeg`: 指定视频编解码器为 MJPEG。
- `-q:v 2`: 设置视频质量，数值范围通常是 2-31，数值越小质量越高。你可以根据需要调整这个值以获得最佳质量和性能平衡。
- `-stream_loop -1`: 使视频文件循环播放无限次。
- `-re`: 按照原始帧率读取文件，模拟实时数据流。
- `-i /home/ubuntu/video.mp4`: 指定输入文件。
- `-map 0:v`: 从输入文件中选择视频流。
- `-vcodec mjpeg`: 使用 MJPEG 编解码器，这是一种每帧都完整压缩的视频流格式，基于 JPEG。
- `-q:v 2`: 设置 JPEG 压缩质量，数值越低质量越高。
- `-f v4l2`: 指定输出格式为 Video4Linux2。
- `/dev/video0`: 指定输出设备。

启用并启动服务

```sh
sudo systemctl enable virtual-webcam.service
sudo systemctl start virtual-cam.service
sudo systemctl restart virtual-cam.service
```

重启即可

```sh
reboot
```

## 虚拟机扩容

遇到了再说吧

在宿主机

检查原始镜像大小：

```sh
qemu-img info ubuntu24.04-x86-64.qcow2
```

扩展镜像大小：

```sh
qemu-img resize ubuntu24.04-x86-64.qcow2 +30G
```

扩展镜像文件后，你需要在镜像的文件系统内部也进行扩展以利用新增的空间。这通常需要挂载镜像并使用文件系统专用的工具，比如 `resize2fs`（对于 ext3/ext4 文件系统）。

进入虚拟机

查找可用的物理存储设备，使用 `lsblk` 或 `fdisk -l` 查找未分配的磁盘或分区。

查看 LVM 配置和状态

```sh
sudo pvs  # 查看物理卷
sudo vgs  # 查看卷组
sudo lvs  # 查看逻辑卷
```

调整卷组和逻辑卷大小

```sh
sudo lvextend -L +10G /dev/mapper/vgname-lvname
# 或者扩展到所有可用空间
sudo lvextend -l +100%FREE /dev/mapper/vgname-lvname
```

## 配置 open-vswitch

力荐[使用Open-vSwitch创建虚拟网络](https://kiosk007.top/post/%E4%BD%BF%E7%94%A8open-vswitch%E6%9E%84%E5%BB%BA%E8%99%9A%E6%8B%9F%E7%BD%91%E7%BB%9C/#openvswtich)这篇博文，写的很全

在宿主机上下载

```sh
sudo apt install openvswitch-switch

systemctl start openvswitch-switch.service
systemctl enable openvswitch-switch.service
```

这边列出 `ovs-vsctl` 的常用命令

- 添加网桥：`ovs-vsctl add-br br0`
- 列出所有网桥：`ovs-vsctl list-br`
- 判断网桥是否存在：`ovs-vsctl br-exists br0`
- 将物理网卡挂接到网桥：`ovs-vsctl add-port br0 eth0`
- 列出网桥中的所有端口：`ovs-vsctl list-ports br0`
- 列出所有挂接到网卡上的网桥：`ovs-vsctl port-to-br eth0`
- 查看OVS 状态：`ovs-vsctl show`
- 查看OVS 的所有Interface、Port 等：`ovs-vsctl list (Interface|Port)` 或 `ovs-vsctl list Port ens37`
- 删除网桥上已经挂接的网口：`vs-vsctl del-port br0 eth0`
- 删除网桥：`ovs-vsctl del-br br0`

**配置无密码sudo**

如果你需要频繁地运行需要超级用户权限的命令（如 `ip`, `ovs-vsctl`, `ovs-ofctl`），有几种方法可以方便地管理这些权限

通过 `which <指令名>` 查找指令目录

```sh
# 使用 visudo 命令以安全方式编辑 sudoers 文件
sudo visudo

# 在打开的文件中添加以下行，替换 'username' 为你的用户名
username ALL=(ALL) NOPASSWD: ALL

# 或者为特定命令配置无密码 sudo：

username ALL=(ALL) NOPASSWD: /usr/sbin/ip, /usr/bin/ovs-vsctl, /usr/bin/ovs-ofctl
```

**启用 Linux 系统的 IP 转发功能**

```sh
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

**创建ovs网桥**

```sh
if ! sudo ovs-vsctl br-exists ovsbr0; then
  sudo ovs-vsctl add-br ovsbr0
fi

# 删除网桥
sudo ovs-vsctl del-br ovsbr0
```

**配置ovs网桥的ip地址**

```sh
sudo ip addr add 192.168.100.1/24 dev ovsbr0

sudo ip addr del 192.168.100.1/24 dev ovsbr0
```

将虚拟机加入到网桥以后，可以在先查看下端口信息 `sudo ovs-vsctl show`。

若端口已经加入，则可以实现选择在虚拟机里设置静态ip或者动态ip

**手动配置 IP 地址**

如果你的网络环境支持静态 IP 或者你已经有指定的 IP 地址范围，你可以手动为 ens3 设置 IP 地址。在虚拟机中执行以下命令：

**很多时候的问题都是接口没有激活，得先up一下**

```sh
sudo ip addr add 192.168.100.10/24 dev ens3
sudo ip link set ens3 up
```

此外，你还需要设置默认网关（通常是你的网络的路由器地址）：

```sh
sudo ip route add default via 192.168.100.1
```

可以写成开机自启动，开机的时候挂载一个hdd的iso

使用 vim 创建脚本文件

```sh
sudo vim /usr/local/bin/mount_and_apply_netplan.sh
```

```sh
#!/bin/bash
mount /dev/sr0 /mnt
cp /mnt/network-config /etc/netplan/01-netcfg.yaml
netplan apply
```

使脚本可执行

```sh
sudo chmod +x /usr/local/bin/mount_and_apply_netplan.sh
```

创建 systemd 服务单元文件

```sh
sudo vim /etc/systemd/system/mount_netplan.service
```

```
[Unit]
Description=Mount sr0 and apply netplan configuration
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount_and_apply_netplan.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

启用并启动服务

```sh
sudo systemctl daemon-reload

sudo systemctl enable mount_netplan.service

sudo systemctl start mount_netplan.service
```

**使用 DHCP 自动获取 IP 地址**

在宿主机上安装dhcp服务器

```sh
sudo apt update
sudo apt install isc-dhcp-server
```

配置 DHCP 服务器

编辑 DHCP 配置文件 `/etc/dhcp/dhcpd.conf`，添加适用于你的网络环境的配置。例如，如果你的 bridge 接口名为 `ovsbr0`，且想要分配的 IP 范围在 `192.168.100.50` 到 `192.168.100.99` 之间：

```sh
sudo vim /etc/dhcp/dhcpd.conf
```

添加内容

```
subnet 192.168.100.0 netmask 255.255.255.0 {
  range 192.168.100.50 192.168.100.99;
  option routers 192.168.100.1;
  option subnet-mask 255.255.255.0;
  option domain-name-servers 8.8.8.8, 8.8.4.4;
  default-lease-time 600;
  max-lease-time 7200;
}
```

指定 DHCP 服务的网络接口

```sh
sudo vim /etc/default/isc-dhcp-server
```

添加或修改以下行，指定你的 bridge 接口：

```
INTERFACES="ovsbr0"
```

启动 DHCP 服务

```sh
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
```

**配置虚拟机**

在新版的ubuntu中，Netplan 是默认的网络配置工具：

找到 Netplan 的配置文件，通常在 `/etc/netplan/` 目录下。打开这个文件进行编辑：

```sh
sudo vim /etc/netplan/01-netcfg.yaml
```

确保配置如下，以允许 `ens3` 接口使用 DHCP：

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      dhcp4: true
```

应用配置更改

```
sudo netplan apply
```

老版需要修改 `/etc/network/interfaces`

```sh
sudo vim /etc/network/interfaces
```

确保有以下行以启用 DHCP：

```
auto ens3
iface ens3 inet dhcp
```

重启网络服务以应用更改：

```sh
sudo systemctl restart networking
```

**配置开机设置网络的服务**

名称为 wfuing_network_init

```sh
sudo vim /etc/wfuing_network_init.sh
```

在编辑器中输入以下内容：

```sh
#!/bin/bash
mkdir -p /mnt
mount /dev/sr0 /mnt
cp /mnt/network-config /etc/netplan/01-netcfg.yaml
netplan apply
```

给脚本执行权限：

```sh
sudo chmod +x /etc/wfuing_network_init.sh
```

创建 systemd 服务文件：

```sh
sudo vim /etc/systemd/system/wfuing_network_init.service
```

在编辑器中添加以下内容：

```
[Unit]
Description=Initialize network settings at startup

[Service]
Type=oneshot
ExecStart=/etc/wfuing_network_init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

启用并启动服务：

```sh
sudo systemctl enable wfuing_network_init.service
sudo systemctl start wfuing_network_init.service
```

**限制端口流量**

定义 QoS 和队列

```sh
# 创建 QoS 规则并同时定义两个队列
sudo ovs-vsctl -- --id=@qos create QoS type=linux-htb other-config:max-rate=250000 queues:1=@q1 queues:2=@q2 -- \
                --id=@q1 create Queue other-config:min-rate=160000 other-config:max-rate=250000 -- \
                --id=@q2 create Queue other-config:min-rate=160000 other-config:max-rate=200000 \
                -- set Port YOUR-BRIDGE-PORT qos=@qos
```

在这个例子中：

- `YOUR-BRIDGE-PORT` 是需要应用带宽限制的端口名称。
- `max-rate` 是最大速率限制，单位是 bps（比特每秒），这里 250000 对应250kbps。
- `min-rate` 是最小速率限制，同样单位是 bps，这里 160000 对应160kbps。
- 创建了两个队列：`@q1` 用于 Multi-tone（限制为250kbps），`@q2` 用于 Single-tone（限制为200kbps）。

应用 QoS 到特定端口，修改上面的命令中的 YOUR-BRIDGE-PORT 来指定正确的端口。

完成配置后，可以使用以下命令来检查 QoS 设置是否已正确应用：

```sh
sudo ovs-vsctl list qos
sudo ovs-vsctl list queue
```

## libvirt操作

- 查看和管理虚拟机
  - 列出所有虚拟机: `virsh list --all`
  - 启动虚拟机: `virsh start <vm_name>`
  - 关闭虚拟机: `virsh shutdown <vm_name>`
  - 强制关闭虚拟机 (类似于断电): `virsh destroy <vm_name>`
  - 重启虚拟机: `virsh reboot <vm_name>`
  - 暂停虚拟机: `virsh suspend <vm_name>`
  - 恢复暂停的虚拟机: `virsh resume <vm_name>`
- 管理虚拟机快照
  - 创建快照: `virsh snapshot-create-as <vm_name> <snapshot_name>`
  - 列出所有快照: `virsh snapshot-list <vm_name>`
  - 恢复快照: `virsh snapshot-revert <vm_name> <snapshot_name>`
  - 删除快照: `virsh snapshot-delete <vm_name> <snapshot_name>`
- 配置和资源管理
  - 查看虚拟机配置: `virsh dumpxml <vm_name>`
  - 编辑虚拟机配置: `virsh edit <vm_name>`
  - 设置虚拟机自动启动: `virsh autostart <vm_name>`
  - 取消虚拟机自动启动: `virsh autostart --disable <vm_name>`
- 网络管理
  - 列出所有网络: `virsh net-list --all`
  - 启动一个网络: `virsh net-start <network_name>`
  - 停止一个网络: `virsh net-destroy <network_name>`
  - 创建网络: `virsh net-create <xml_file>`
  - 编辑网络配置: `virsh net-edit <network_name>`
- 存储管理
  - 列出所有存储池: `virsh pool-list --all`
  - 创建存储池: `virsh pool-create <xml_file>`
  - 删除存储池: `virsh pool-destroy <pool_name>`
  - 查看存储池信息: `virsh pool-info <pool_name>`

如果要在启动一个pool路径下的虚拟机 

需要给 pool 路径上所有的文件夹目录赋权限，才能使用

```sh
sudo chown -R libvirt-qemu:kvm /home/wfuing/test/images/
sudo chmod -R 775 /home/wfuing/test/images/
sudo chmod -R 775 /home/wfuing/test
sudo chmod -R 775 /home/wfuing
# 将一个用户加入组
sudo gpasswd -a username groupname
# 查看用户的群组信息
id username
# 列出群组成员
getent group groupname
```

**virsh console**

如果要[连接到console](https://serverfault.com/questions/364895/virsh-vm-console-does-not-show-any-output)，需要在配置文件中先加上

```xml
<serial type='pty'>
  <target port='0'/>
</serial>
<console type='pty'>
  <target type='serial' port='0'/>
</console>
```

然后在虚拟机中启动

```sh
systemctl enable serial-getty@ttyS0.service
systemctl start serial-getty@ttyS0.service
```



```
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

data "template_file" "user_data" {
  count    = var.vm_count
  template = file("${path.module}/user_data.yaml")
  vars = {
    name = "vm-${count.index}"
  }
}
```


## 运行 Actor

```sh
go run head/main.go head --addr <head_addr> --port <head_port>
go run worker/main.go --addr <worker_addr> --remote_addr <head_addr> --remote_port <head_port>
```



