#!/bin/bash

# 确保脚本在正确的目录下运行
cd "$(dirname "$0")/.." || exit 1

# 源引入通用函数
source scripts/common.sh

# 定义函数
build_package_repo() {
    local config_file=$1
    local package_info=$(cat "$config_file")

    local package_name=$(echo "$package_info" | jq -r .name)
    local source_type=$(echo "$package_info" | jq -r .source.type)

    echo "Processing package: $package_name"
    echo "Source type: $source_type"
    local new_version
    if [ "$source_type" = "github" ]; then
        local github_repo=$(echo "$package_info" | jq -r .source.repo)
        new_version=$(get_latest_version_gh "$github_repo")
    else
        version_url=$(jq -r '.source.version_url' "$config")
        version_pattern=$(jq -r '.source.version_pattern' "$config")
        new_version=$(get_latest_version_d "$version_url" "$version_pattern")
    fi

    local current_version=$(cat "version-lock/${package_name}.lock" 2>/dev/null || echo "0")
    echo "Current version: $current_version"
    echo "New version: $new_version"

    if [ "$current_version" = "$new_version" ]; then
        echo "${package_name} is already up to date"
        return 0
    fi
    echo "Updating ${package_name} from ${current_version} to ${new_version}"

    create_repo_structure "$package_name"

    local architectures=$(echo "$package_info" | jq -r '.package.architectures[]')
    for arch in $architectures; do
        if [ "$source_type" = "github" ]; then
            local pattern=$(echo "$package_info" | jq -r ".source.asset_patterns.${arch}")
            download_package_gh "$github_repo" "$new_version" "$arch" "$pattern" "$package_name"
        else
            local url=$(echo "$package_info" | jq -r .source.url)
            download_package_d "$url" "$new_version" "$arch" "$package_name"
        fi
    done

    echo "Updating version lock file"
    echo "$new_version" >"version-lock/${package_name}.lock"
    echo "Version lock file updated"
}

generate_repo_metadata() {
    ROOT_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
    CONF_FILE="${ROOT_DIR}/apt-ftparchive.conf"

    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
        if ls pool/*/*_${arch}.deb 1>/dev/null 2>&1; then
            dpkg-scanpackages --arch ${arch} pool/ >"dists/stable/main/binary-${arch}/Packages"
            gzip -k -f "dists/stable/main/binary-${arch}/Packages"
        fi
    done

    # shellcheck disable=SC2164
    cd dists/stable
    apt-ftparchive -c "${CONF_FILE}" release . >Release

    # Sign with imported GPG key
    gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --clearsign -o InRelease Release
    gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" -abs -o Release.gpg Release

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
