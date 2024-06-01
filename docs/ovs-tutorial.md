

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

