#!/bin/bash
set -e


if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

REPO_URL="https://atticuszeller.github.io/deb-index"
REPO_NAME="deb-index"
GPG_KEY_URL="${REPO_URL}/public.key"

echo "Adding GPG key..."
curl -fsSL "${GPG_KEY_URL}" | apt-key add -

echo "Adding repository..."
echo "deb ${REPO_URL} stable main" | tee "/etc/apt/sources.list.d/${REPO_NAME}.list"

echo "Updating package lists..."
apt update

echo "Repository successfully added!"
echo "You can now install packages using: apt install <package-name>"
