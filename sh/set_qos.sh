#!/bin/bash

# 检查是否提供了桥接名称
if [ -z "$1" ]; then
    echo "Usage: $0 <bridge-name>"
    exit 1
fi

BRIDGE_NAME="$1"

# 获取指定桥的所有端口
PORTS=$(sudo ovs-vsctl list-ports "$BRIDGE_NAME")
if [ $? -ne 0 ]; then
    echo "Failed to get ports for bridge $BRIDGE_NAME"
    exit 1
fi

# 创建 QoS 配置和两个队列，并将它们应用到每个端口
for PORT in $PORTS; do
    # 创建 QoS 和队列，并应用到端口
    sudo ovs-vsctl -- --id=@qos create QoS type=linux-htb other-config:max-rate=250000 queues:1=@q1 queues:2=@q2 \
                   -- --id=@q1 create Queue other-config:min-rate=160000 other-config:max-rate=250000 \
                   -- --id=@q2 create Queue other-config:min-rate=160000 other-config:max-rate=200000 \
                   -- set Port "$PORT" qos=@qos
    if [ $? -ne 0 ]; then
        echo "Failed to set QoS for port $PORT"
    else
        echo "Set QoS for port $PORT successfully"
    fi
done

echo "All operations completed"
