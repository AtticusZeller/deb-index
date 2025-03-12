#!/bin/bash

# Get the minor version from a full version string (e.g., 1.15.3 -> 1.15)
get_minor_version() {
    local full_version=$1
    # Remove leading 'v' if present
    full_version=${full_version#v}
    # Extract the first two segments (major.minor)
    echo "$full_version" | grep -o '^[0-9]\+\.[0-9]\+'
}

# Get all versions from GitHub that match the specified minor version
get_versions_by_minor() {
    local repo=$1
    local minor_version=$2
    
    # Get all releases
    local all_releases=$(curl -s "https://api.github.com/repos/${repo}/releases" | jq -r '.[].tag_name')
    
    # Filter releases by minor version
    for version in $all_releases; do
        # Remove leading 'v' if present
        clean_version=${version#v}
        # Get minor version
        ver_minor=$(get_minor_version "$version")
        
        if [ "$ver_minor" = "$minor_version" ]; then
            echo "$version"
        fi
    done
}

# Get the latest minor version from GitHub releases
get_latest_minor_version() {
    local repo=$1
    local latest_version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name)
    get_minor_version "$latest_version"
}

# Get all asset URLs for a specific version and architecture
get_assets_for_version() {
    local repo=$1
    local version=$2
    local arch=$3
    local pattern=$4
    
    # Get the specific release by tag
    curl -s "https://api.github.com/repos/${repo}/releases/tags/${version}" | 
        jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url'
}