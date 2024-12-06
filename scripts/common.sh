#!/bin/bash

create_repo_structure() {
    local package_name=$1
    mkdir -p "pool/${package_name}"
    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
    done
}
# 从直接链接获取版本号
get_latest_version_d() {
    local version_url=$1
    local version_pattern=$2
    local download_pattern=$3

    echo "[DEBUG] Fetching from: $version_url"
    echo "[DEBUG] Using download pattern: $download_pattern"
    
    local html_content=$(curl -s "$version_url")
    local download_link=$(echo "$html_content" | grep -o "$download_pattern" | head -n 1)
    
    echo "[DEBUG] Found download link: $download_link"
    
    if [[ $download_link =~ $version_pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "[ERROR] Failed to extract version from link: $download_link"
        return 1
    fi
}

# 下载包
download_package_d() {
    local url=$1
    local version=$2
    local arch=$3
    local package_name=$4

    local download_url=${url/\{version\}/$version}
    echo "Downloading package for ${arch}..."

    wget -q -O "pool/${package_name}/${package_name}_${version}_${arch}.deb" "$download_url"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully downloaded ${arch} package"
        return 0
    else
        echo "✗ Failed to download ${arch} package"
        return 1
    fi
}

get_latest_version_gh() {
    local repo=$1
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name
}

download_package_gh() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    local package_name=$5

    local asset_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" |
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
