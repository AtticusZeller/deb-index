#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/repo/scripts" "$work/bin" "$work/assets" "$work/package/DEBIAN"
cp "$root"/scripts/*.sh "$work/repo/scripts/"
cp "$root/apt-ftparchive.conf" "$work/repo/"
export TEST_ASSETS="$work/assets" TEST_RELEASE="$work/release.json"
cat > "$work/bin/gh" <<'MOCK'
#!/bin/bash
set -euo pipefail
if [[ "$1" == api ]]; then
    cat "$TEST_RELEASE"
else
    [[ "${TEST_DOWNLOAD_FAIL:-0}" != 1 ]] || exit 1
    shift 3
    while (( $# )); do
        case "$1" in
            --repo) shift 2 ;;
            --pattern) asset=$2; shift 2 ;;
            --dir) destination=$2; shift 2 ;;
            *) exit 1 ;;
        esac
    done
    cp "$TEST_ASSETS/$asset" "$destination/"
fi
MOCK
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"
cat > "$work/package/DEBIAN/control" <<'CONTROL'
Package: sing-box
Version: 1.2.3
Architecture: amd64
Maintainer: Test <test@example.com>
Description: Build regression fixture
CONTROL
dpkg-deb --build "$work/package" "$work/assets/SFL-1.2.3-amd64.deb" >/dev/null
cat > "$work/repo/package.json" <<'CONFIG'
{"package":{"name":"sing-box","architectures":["amd64"]},"source":{"repo":"example/repo","asset_patterns":{"amd64":"^SFL-.*-amd64\\.deb$"}}}
CONFIG
printf '%s\n' '{"draft":false,"prerelease":false,"tag_name":"v1.2.3","assets":[{"name":"SFL-1.2.3-amd64.deb"}]}' > "$TEST_RELEASE"
mkdir -p "$work/repo/pool/sing-box"
cp "$work/assets/SFL-1.2.3-amd64.deb" "$work/repo/pool/sing-box/old_amd64.deb"
bash "$work/repo/scripts/build-repo.sh" "$work/repo/package.json"
[[ $(find "$work/repo/pool" -name '*.deb' | wc -l) == 1 ]]
latest="$work/repo/pool/sing-box/sing-box_1.2.3_amd64.deb"
[[ -f "$latest" && ! -f "$work/repo/pool/sing-box/old_amd64.deb" ]]
rm "$latest"
bash "$work/repo/scripts/build-repo.sh" "$work/repo/package.json"
[[ -f "$latest" ]]

expect_failure() {
    if bash "$work/repo/scripts/build-repo.sh" "$work/repo/package.json" >/dev/null 2>&1; then
        echo "Expected build failure" >&2
        exit 1
    fi
    [[ -f "$latest" ]]
}
TEST_DOWNLOAD_FAIL=1 expect_failure
cp "$TEST_RELEASE" "$work/good.json"
jq '.assets=[]' "$work/good.json" > "$TEST_RELEASE"
expect_failure
jq '.assets += [{"name":"SFL-1.2.4-amd64.deb"}]' "$work/good.json" > "$TEST_RELEASE"
expect_failure
jq '.prerelease=true' "$work/good.json" > "$TEST_RELEASE"
expect_failure
cp "$work/good.json" "$TEST_RELEASE"
sed -i 's/Architecture: amd64/Architecture: arm64/' "$work/package/DEBIAN/control"
dpkg-deb --build "$work/package" "$work/assets/SFL-1.2.3-amd64.deb" >/dev/null
expect_failure
sed -i 's/Architecture: arm64/Architecture: amd64/; s/Package: sing-box/Package: wrong-name/' "$work/package/DEBIAN/control"
dpkg-deb --build "$work/package" "$work/assets/SFL-1.2.3-amd64.deb" >/dev/null
expect_failure

export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key 'APT test <apt@example.com>' rsa2048 sign 0 >/dev/null 2>&1
bash "$work/repo/scripts/build-repo.sh" --generate-metadata
release_dir="$work/repo/dists/stable"
gpg --verify "$release_dir/InRelease" >/dev/null 2>&1
gpg --verify "$release_dir/Release.gpg" "$release_dir/Release" >/dev/null 2>&1
[[ ! -s "$release_dir/main/binary-arm64/Packages" ]]
[[ ! -s "$release_dir/main/binary-armhf/Packages" ]]
rg -q '^Package: sing-box$' "$release_dir/main/binary-amd64/Packages"
rg -q '^Filename: pool/sing-box/sing-box_1.2.3_amd64.deb$' "$release_dir/main/binary-amd64/Packages"
echo 'PASS: latest-only, missing package with lock, failed download, absent/ambiguous assets, prerelease, wrong package/architecture, signed metadata and empty indexes'
