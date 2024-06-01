#!/bin/bash

# 获取所有 OVS 网桥
bridges=$(sudo ovs-vsctl list-br)

# 检查是否有任何网桥存在
if [ -z "$bridges" ]; then
  echo "No OVS bridges found."
  exit 0
fi

# 遍历所有网桥并删除
for bridge in $bridges; do
  echo "Deleting OVS bridge: $bridge"
  sudo ovs-vsctl del-br "$bridge"
done

echo "All OVS bridges have been deleted."
sudo ovs-vsctl list-br