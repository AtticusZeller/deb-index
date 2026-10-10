#!/bin/bash

# Download into a temporary directory and validate before replacing a package.
download_package() {
    local repo=$1 version=$2 asset=$3 package_name=$4 arch=$5
    local destination=$6
    local temporary_dir
    temporary_dir=$(mktemp -d)

    if ! gh release download "$version" --repo "$repo" --pattern "$asset" --dir "$temporary_dir"; then
        rm -rf "$temporary_dir"
        return 1
    fi

    local downloaded="$temporary_dir/$asset"
    local actual_name actual_arch
    actual_name=$(dpkg-deb -f "$downloaded" Package) || { rm -rf "$temporary_dir"; return 1; }
    actual_arch=$(dpkg-deb -f "$downloaded" Architecture) || { rm -rf "$temporary_dir"; return 1; }
    if [[ "$actual_name" != "$package_name" || "$actual_arch" != "$arch" ]]; then
        echo "Unexpected package: $actual_name/$actual_arch; expected $package_name/$arch" >&2
        rm -rf "$temporary_dir"
        return 1
    fi

    mv "$downloaded" "$destination"
    rm -rf "$temporary_dir"
}
