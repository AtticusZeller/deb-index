#!/bin/bash

# 检查并创建必要的目录结构
create_repo_structure() {
    local package_name=$1
    mkdir -p "pool/${package_name}"
    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
    done
}

# 获取 GitHub 最新版本
get_latest_version() {
    local repo=$1
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name
}

# 下载特定架构的包
download_package() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    local package_name=$5
    
    local asset_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
        jq -r ".assets[] | select(.name | test(\"${pattern}\")) | .browser_download_url")
    
    if [ ! -z "$asset_url" ]; then
        wget -O "pool/${package_name}/${package_name}_${version}_${arch}.deb" "$asset_url"
        return 0
    fi
    return 1
}
