
首先你需要先配置qemu虚拟机中的环境，目前这一步没有配置自动化

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

## 网络配置开机启动

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


## 运行 Actor

```sh
go run head/main.go head --addr <head_addr> --port <head_port>
go run worker/main.go --addr <worker_addr> --remote_addr <head_addr> --remote_port <head_port>
```


## virsh console

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
