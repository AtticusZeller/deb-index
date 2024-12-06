#!/bin/bash

# 确保脚本在正确的目录下运行
cd "$(dirname "$0")/.." || exit 1

# 源引入通用函数
source scripts/common.sh

# 定义函数
build_package_repo() {
    local config_file=$1
    local package_info=$(cat "$config_file")
    
    # 解析配置
    local package_name=$(echo "$package_info" | jq -r .name)
    local github_repo=$(echo "$package_info" | jq -r .source.repo)
    echo "Processing package: $package_name"
    echo "GitHub repo: $github_repo"
    # 获取最新版本
    local new_version=$(get_latest_version "$github_repo")
    local current_version=$(cat "version-lock/${package_name}.lock" 2>/dev/null || echo "0")
    echo "Current version: $current_version"
    echo "New version: $new_version"
    # 检查是否需要更新
    if [ "$current_version" = "$new_version" ]; then
        echo "${package_name} is already up to date"
        return 0
    fi
    echo "Updating ${package_name} from ${current_version} to ${new_version}"
    # 创建目录结构
    create_repo_structure "$package_name"
    
    # 下载各架构包
    local architectures=$(echo "$package_info" | jq -r '.package.architectures[]')
    for arch in $architectures; do
        local pattern=$(echo "$package_info" | jq -r ".source.asset_patterns.${arch}")
        download_package "$github_repo" "$new_version" "$arch" "$pattern" "$package_name"
    done
    
     # 更新版本锁定文件
    echo "Updating version lock file"
    echo "$new_version" > "version-lock/${package_name}.lock"
    echo "Version lock file updated"
}

generate_repo_metadata() {
    ROOT_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
    CONF_FILE="${ROOT_DIR}/apt-ftparchive.conf"

    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
        if ls pool/*/*_${arch}.deb 1> /dev/null 2>&1; then
            dpkg-scanpackages --arch ${arch} pool/ > "dists/stable/main/binary-${arch}/Packages"
            gzip -k -f "dists/stable/main/binary-${arch}/Packages"
        fi
    done

    cd dists/stable
    apt-ftparchive -c "${CONF_FILE}" release . > Release
    # 创建空的 InRelease 和 Release.gpg 文件来避免警告
    touch InRelease
    touch Release.gpg
    cd ../..
}






# 处理命令行参数
if [ "$1" = "--generate-metadata" ]; then
    generate_repo_metadata
    exit 0
fi

# 处理配置文件
if [ -f "$1" ]; then
    build_package_repo "$1"
else
    echo "Usage: $0 <config-file> or $0 --generate-metadata"
    exit 1
fi
