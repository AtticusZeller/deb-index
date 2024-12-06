#!/bin/bash

create_repo_structure() {
    local package_name=$1
    mkdir -p "pool/${package_name}"
    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
    done
}

get_latest_version_d() {
    local version_url=$1
    local version_pattern=$2

    # 检查输入参数
    echo "[DEBUG] version_url: $version_url"
    echo "[DEBUG] version_pattern: $version_pattern"

    # 获取HTML内容并提取下载链接
    local html_content=$(curl -s "$version_url")
    if [[ -z $html_content ]]; then
        echo "[ERROR] Failed to fetch HTML content from $version_url"
        return 1
    fi

    echo "[DEBUG] HTML content fetched (truncated):"
    echo "${html_content:0:500}..." # 仅显示前500字符避免过多输出

    # 提取下载链接
    local download_link=$(echo "$html_content" | grep -o "https://.*_amd64.*\.deb" | head -n 1)
    if [[ -z $download_link ]]; then
        echo "[ERROR] No download link found matching '_amd64.*.deb'"
        return 2
    fi

    echo "[DEBUG] Download link found: $download_link"

    # 从下载链接中提取版本号
    if [[ $download_link =~ $version_pattern ]]; then
        echo "[DEBUG] Version pattern matched: ${BASH_REMATCH[1]}"
        echo "${BASH_REMATCH[1]}"
    else
        echo "[ERROR] Download link does not match the version pattern."
        echo "[DEBUG] Version pattern: $version_pattern"
        echo "[DEBUG] Download link: $download_link"
        return 3
    fi
}




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
