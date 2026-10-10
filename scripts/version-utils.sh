#!/bin/bash

get_latest_release() {
    local repo=$1
    gh api "repos/${repo}/releases/latest" |
        jq -e 'select(.draft == false and .prerelease == false and (.tag_name | type == "string"))'
}

get_asset_name() {
    local release=$1
    local pattern=$2
    echo "$release" | jq -er --arg pattern "$pattern" '
        [.assets[] | select(.name | test($pattern)) | .name] |
        if length == 1 then .[0]
        else error("Expected exactly one release asset, found \(length)") end'
}
