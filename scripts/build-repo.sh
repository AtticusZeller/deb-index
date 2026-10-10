#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/common.sh
source scripts/version-utils.sh

build_package_repo() {
    local config_file=$1 package_name github_repo release version arch pattern asset deb_file
    package_name=$(jq -er '.package.name' "$config_file")
    github_repo=$(jq -er '.source.repo' "$config_file")
    release=$(get_latest_release "$github_repo")
    version=$(echo "$release" | jq -er '.tag_name')
    if [[ ! "$version" =~ ^v?[0-9]+([.][0-9]+)*([-+~][a-zA-Z0-9.-]+)?$ ]]; then
        echo "Unsupported release tag: $version" >&2
        return 1
    fi
    echo "Processing $package_name: latest stable release $version"
    mkdir -p "pool/$package_name" version-lock
    local -a architectures keep_files
    mapfile -t architectures < <(jq -er '.package.architectures[]' "$config_file")
    [[ ${#architectures[@]} -gt 0 ]]
    keep_files=()
    for arch in "${architectures[@]}"; do
        pattern=$(jq -er --arg arch "$arch" '.source.asset_patterns[$arch]' "$config_file")
        asset=$(get_asset_name "$release" "$pattern")
        deb_file="pool/$package_name/${package_name}_${version#v}_${arch}.deb"
        # Always fetch latest: locks or files from another source must not mask a missing/new asset.
        download_package "$github_repo" "$version" "$asset" "$package_name" "$arch" "$deb_file"
        keep_files+=("$deb_file")
    done
    local old_file keep
    for old_file in "pool/$package_name/"*.deb; do
        [[ -e "$old_file" ]] || continue
        keep=false
        for deb_file in "${keep_files[@]}"; do
            [[ "$old_file" != "$deb_file" ]] || keep=true
        done
        if [[ "$keep" == false ]]; then
            rm -- "$old_file"
        fi
    done
    printf 'version: %s\n' "$version" > "version-lock/$package_name.lock"
}

generate_repo_metadata() {
    local root_dir arch
    root_dir=$PWD
    # Rebuild all indexes, including empty architectures, so stale entries never survive.
    rm -rf dists/stable
    for arch in amd64 arm64; do
        mkdir -p "dists/stable/main/binary-$arch"
        dpkg-scanpackages --multiversion --arch "$arch" pool/ > "dists/stable/main/binary-$arch/Packages"
        gzip -k -f "dists/stable/main/binary-$arch/Packages"
    done
    (
        cd dists/stable
        apt-ftparchive -c "$root_dir/apt-ftparchive.conf" release . > Release
        # The imported signing key and its passphrase are supplied by the workflow.
        gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 --clearsign -o InRelease Release 3<<<"${GPG_PASSPHRASE:-}"
        gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 -abs -o Release.gpg Release 3<<<"${GPG_PASSPHRASE:-}"
    )
}

if [[ "${1:-}" == "--generate-metadata" ]]; then
    generate_repo_metadata
elif [[ -f "${1:-}" ]]; then
    build_package_repo "$1"
else
    echo "Usage: $0 <config-file> or $0 --generate-metadata" >&2
    exit 1
fi
