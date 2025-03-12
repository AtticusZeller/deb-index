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

    # get latest minor version (e.g., 1.15)
    local latest_minor_version=$(get_latest_minor_version "$github_repo")

    # get the current minor version from the lock file
    local current_minor_version=$(get_locked_minor_version "$package_name")
    echo "Current minor version: $current_minor_version"
    echo "Latest minor version: $latest_minor_version"

    # get downloaded versions from the lock file
    local downloaded_versions=$(get_downloaded_versions "$package_name")
    echo "Previously downloaded versions: $downloaded_versions"

    # fetch all available versions under the latest minor version
    local all_available_versions=$(get_versions_by_minor "$github_repo" "$latest_minor_version")
    echo "All available versions for $latest_minor_version: $all_available_versions"

    # decide which versions to download
    local versions_to_download=""
    if [ "$current_minor_version" != "$latest_minor_version" ]; then
        # download all versions if the minor version has changed
        echo "Minor version changed from $current_minor_version to $latest_minor_version, downloading all versions"
        versions_to_download="$all_available_versions"
    else
        # only download versions that have not been downloaded yet
        for version in $all_available_versions; do
            if ! echo "$downloaded_versions" | grep -q "$version"; then
                versions_to_download="$versions_to_download $version"
            fi
        done
    fi

    if [ -z "$versions_to_download" ]; then
        echo "No new versions to download for $package_name"
        return 0
    fi

    echo "Versions to download: $versions_to_download"

    create_repo_structure "$package_name"

    # download new versions
    local new_downloaded_versions=""
    local architectures=$(echo "$package_info" | jq -r '.package.architectures[]')

    for version in $versions_to_download; do
        echo "Processing version: $version"
        local success=true

        for arch in $architectures; do
            local pattern=$(echo "$package_info" | jq -r ".source.asset_patterns.${arch}")
            if ! download_package_by_version "$github_repo" "$version" "$arch" "$pattern" "$package_name"; then
                success=false
                break
            fi
        done

        if $success; then
            new_downloaded_versions="$new_downloaded_versions $version"
        fi
    done

    # update lock file
    if [ ! -z "$new_downloaded_versions" ]; then
        # merge old and new downloaded versions
        if [ "$current_minor_version" = "$latest_minor_version" ]; then
            downloaded_versions="$downloaded_versions $new_downloaded_versions"
        else
            downloaded_versions="$new_downloaded_versions"
        fi

        echo "Updating version lock file"
        save_versions_to_lock "$package_name" "$latest_minor_version" "$downloaded_versions"
        echo "Version lock file updated"
    else
        echo "No new versions were successfully downloaded, lock file not updated"
    fi
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
