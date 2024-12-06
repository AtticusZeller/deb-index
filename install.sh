#!/bin/bash

# 检测系统架构
ARCH=$(dpkg --print-architecture)

# 添加仓库
echo "deb [trusted=yes] https://atticuszeller.github.io/clash-verge-rev-deb stable main" | \
    sudo tee /etc/apt/sources.list.d/clash-verge-rev.list

# 更新并安装
sudo apt update
sudo apt install clash-verge-rev
