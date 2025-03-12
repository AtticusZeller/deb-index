#!/bin/bash

# build-repo.sh
cd "$(dirname "$0")/.." || exit 1
source scripts/common.sh
source scripts/version-utils.sh

build_package_repo() {
    local config_file=$1
    local package_info=$(cat "$config_file")

    local package_name=$(echo "$package_info" | jq -r .name)
    local github_repo=$(echo "$package_info" | jq -r .source.repo)

    echo "Processing package: $package_name"
    
    # Get the latest minor version (e.g., 1.15)
    local latest_minor_version=$(get_latest_minor_version "$github_repo")
    
    # Check if we have a record of the current minor version
    local current_minor_version=$(cat "version-lock/${package_name}.lock" 2>/dev/null || echo "0")
    echo "Current minor version: $current_minor_version"
    echo "Latest minor version: $latest_minor_version"

    # if [ "$current_minor_version" = "$latest_minor_version" ]; then
    #     echo "${package_name} minor version is already up to date"
    #     return 0
    # fi
    
    echo "Updating ${package_name} from minor version ${current_minor_version} to ${latest_minor_version}"

    create_repo_structure "$package_name"

    # Get all versions that match the latest minor version
    local matching_versions=$(get_versions_by_minor "$github_repo" "$latest_minor_version")
    echo "Found the following versions for minor $latest_minor_version: $matching_versions"
    
    # Process each architecture for each matching version
    local architectures=$(echo "$package_info" | jq -r '.package.architectures[]')
    
    for version in $matching_versions; do
        echo "Processing version: $version"
        
        for arch in $architectures; do
            local pattern=$(echo "$package_info" | jq -r ".source.asset_patterns.${arch}")
            download_package_by_version "$github_repo" "$version" "$arch" "$pattern" "$package_name"
        done
    done

    echo "Updating version lock file with new minor version"
    echo "$latest_minor_version" > "version-lock/${package_name}.lock"
    echo "Version lock file updated"
}

# Download a specific version of a package
download_package_by_version() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    local package_name=$5

    # Get asset URL for this specific version
    local asset_url=$(get_assets_for_version "$repo" "$version" "$arch" "$pattern")

    if [ ! -z "$asset_url" ]; then
        # Clean version for filename (remove leading 'v' if present)
        local clean_version=${version#v}
        
        echo "Downloading package ${package_name} version ${clean_version} for ${arch}..."
        wget -q -O "pool/${package_name}/${package_name}_${clean_version}_${arch}.deb" "$asset_url"
        if [ $? -eq 0 ]; then
            echo "✓ Successfully downloaded ${arch} package for version ${clean_version}"
            return 0
        else
            echo "✗ Failed to download ${arch} package for version ${clean_version}"
            return 1
        fi
    fi
    echo "! No matching asset found for ${arch} in version ${version}"
    return 1
}

generate_repo_metadata() {
    ROOT_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
    CONF_FILE="${ROOT_DIR}/apt-ftparchive.conf"

    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
        if ls pool/*/*_${arch}.deb 1>/dev/null 2>&1; then
            dpkg-scanpackages --arch ${arch} pool/ > "dists/stable/main/binary-${arch}/Packages"
            gzip -k -f "dists/stable/main/binary-${arch}/Packages"
        fi
    done

    cd dists/stable
    apt-ftparchive -c "${CONF_FILE}" release . > Release
    gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --clearsign -o InRelease Release
    gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" -abs -o Release.gpg Release
    cd ../..
}

if [ "$1" = "--generate-metadata" ]; then
    generate_repo_metadata
    exit 0
fi

if [ -f "$1" ]; then
    build_package_repo "$1"
else
    echo "Usage: $0 <config-file> or $0 --generate-metadata"
    exit 1
fi