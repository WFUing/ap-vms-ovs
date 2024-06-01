#!/bin/bash

# 获取所有虚拟机的名称，包括已停止的虚拟机
vms=$(virsh list --all --name)

# 遍历所有虚拟机名称，过滤出以 worker 和 head 开头的虚拟机
for vm in $vms; do
  if [[ $vm == worker* ]] || [[ $vm == head* ]]; then
    echo "Deleting virtual machine: $vm"
    
    # 检查虚拟机是否正在运行，如果是则先关闭
    if virsh dominfo "$vm" | grep -q "State: *running"; then
      virsh shutdown "$vm"
      # 等待虚拟机关闭
      while [[ $(virsh list --name | grep -w "$vm") ]]; do
        echo "Waiting for $vm to shut down..."
        sleep 1
      done
    fi

    # 删除虚拟机及其所有存储
    virsh undefine "$vm" --remove-all-storage
    echo "Virtual machine $vm deleted."
  fi
done

echo "All matching virtual machines have been deleted."

#!/bin/bash

# 获取所有存储池名称
pools=$(virsh pool-list --all --name)

# 过滤出以 vm-storage-pool 结尾的存储池并删除
for pool in $pools; do
  if [[ $pool == *vm-storage-pool ]]; then
    echo "Deleting storage pool: $pool"
    
    # 检查存储池是否是活动状态，如果是则先销毁
    if virsh pool-info "$pool" | grep -q "State: *running"; then
      echo "$poll active"
      virsh pool-destroy "$pool"
    fi
    
    # 删除存储池定义
    virsh pool-undefine "$pool"
    
    echo "Storage pool $pool deleted."
  fi
done

echo "All matching storage pools have been deleted."

#!/bin/bash

# 获取所有网络名称
networks=$(virsh net-list --all --name)

# 过滤出以 network 结尾的网络并删除
for net in $networks; do
  if [[ $net == *network ]]; then
    echo "Deleting network: $net"
    
    # 检查网络是否是活动状态，如果是则先销毁
    if virsh net-info "$net" | grep -q "Active: *yes"; then
      virsh net-destroy "$net"
    fi
    
    # 删除网络定义
    virsh net-undefine "$net"
    
    echo "Network $net deleted."
  fi
done

echo "All matching networks have been deleted."

echo "now vm:"
virsh list --all
echo "now pool-list:"
virsh pool-list --all
echo "now net-list:"
virsh net-list --all