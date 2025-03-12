#!/bin/bash

create_repo_structure() {
    local package_name=$1
    mkdir -p "pool/${package_name}"
    for arch in amd64 arm64 armhf; do
        mkdir -p "dists/stable/main/binary-${arch}"
    done
}

# Download a specific version of a package
download_package_by_version() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    local package_name=$5

    # check if the package already exists
    local clean_version=${version#v}
    local deb_file="pool/${package_name}/${package_name}_${clean_version}_${arch}.deb"

    if [ -f "$deb_file" ]; then
        echo "✓ Package ${package_name} version ${clean_version} for ${arch} already exists"
        return 0
    fi

    local asset_url=$(get_assets_for_version "$repo" "$version" "$arch" "$pattern")

    if [ ! -z "$asset_url" ]; then
        echo "Downloading package ${package_name} version ${clean_version} for ${arch}..."
        wget -q -O "$deb_file" "$asset_url"
        if [ $? -eq 0 ]; then
            echo "✓ Successfully downloaded ${arch} package for version ${clean_version}"
            return 0
        else
            echo "✗ Failed to download ${arch} package for version ${clean_version}"
            rm -f "$deb_file"
            return 1
        fi
    fi
    echo "! No matching asset found for ${arch} in version ${version}"
    return 1
}
