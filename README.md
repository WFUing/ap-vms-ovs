
实验最后的效果如下图：

![](img/apvm.png)

## 准备环境

- 安装qemu、libvirt、virt-manager、terraform、ovs
  - libvirt操作请见 [libvirt常用操作](docs/libvirt-tutorial.md)
  - openvswitch操作请见 [openvswitch操作](docs/ovs-tutorial.md)
- 拿到已经准备好的ubuntu镜像，用config.xml实现安装
  - 如果你想研究qemu的虚拟机中的配置，可以看 [qemu虚拟机中的环境配置](docs/qemu-vm-preparation.md)

注意：这边会有很多linux的权限问题，请按照报错提示慢慢解决！下面给出其中一种权限问题：

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

这个terraform脚本使用了魔改过的openvswitch的provider，具体请见https://github.com/WFUing/terraform-provider-openvswitch

> 注意：ip、ovs-vsctl、ovs-ofctl 命令都需要 sudo 或 root 权限

## 具体操作

在./sh中，

- run.sh：是运行整个terraform脚本的代码
- delete_vm_storage_net.sh：清理代码部署以后的环境，在每次运行terraform脚本前，请先运行该程序
- set_qos.sh：限制openvswitch的流量，请根据根据实际需要调整

