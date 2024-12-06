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

download_package() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    local package_name=$5
    
    local asset_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
        jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url')
    
    if [ ! -z "$asset_url" ]; then
        echo "Downloading package for ${arch}..."
        # 添加 -q 参数隐藏下载进度
        wget -q -O "pool/${package_name}/${package_name}_${version}_${arch}.deb" "$asset_url"
        if [ $? -eq 0 ]; then
            echo "✓ Successfully downloaded ${arch} package"
            return 0
        else
            echo "✗ Failed to download ${arch} package"
            return 1
        fi
    fi
    echo "! No matching asset found for ${arch}"
    return 1
}
