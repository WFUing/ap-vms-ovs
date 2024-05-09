
# 查看所有的虚拟机
virsh list --all

# 查看网络状态
virsh net-list --all

virsh net-start default

virsh net-autostart default

virsh shutdown vm-0
virsh shutdown vm-1
virsh shutdown vm-2

# 删除虚拟机
virsh undefine vm-0 --remove-all-storage
virsh undefine vm-1 --remove-all-storage
virsh undefine vm-2 --remove-all-storage

virsh shutdown worker-vm-0 
virsh shutdown worker-vm-1 
virsh shutdown worker02-vm-0 
virsh shutdown worker02-vm-1 
virsh shutdown head-vm 

virsh undefine worker-vm-0 --remove-all-storage
virsh undefine worker-vm-1 --remove-all-storage
virsh undefine worker02-vm-0 --remove-all-storage
virsh undefine worker02-vm-1 --remove-all-storage
virsh undefine head-vm --remove-all-storage
