# DEB Index

Automatically publishes an APT repository at https://docs.atticux.me/deb-index.
GitHub Actions downloads each application's latest stable release, generates signed APT indexes,
and deploys a GitHub Pages artifact. DEB files are not committed to Git. Each build starts fresh
and retains one release per application, for every configured architecture.

## Supported packages

| APT package | Upstream | Architectures |
| --- | --- | --- |
| `sing-box` (SFL desktop client) | [SagerNet/sing-box](https://github.com/SagerNet/sing-box/releases), `SFL-*.deb` | amd64 |
| `alacritty` | [AtticusZeller/alacritty-deb](https://github.com/AtticusZeller/alacritty-deb/releases) | amd64 |

SFL's Debian package name is `sing-box`. This repository serves the desktop client under that
name; there is no separate `sing-box-desktop` package.
GUI applications are published for amd64 only. Command-line tools may use amd64 or arm64;
armhf is not supported. Both currently configured applications are GUI applications.

## Add repository

```bash
curl -fsSL https://docs.atticux.me/deb-index/install.sh | sudo bash
sudo apt install sing-box
```

Or manually:

```bash
sudo install -d -m 755 /etc/apt/keyrings
curl -fsSL https://docs.atticux.me/deb-index/public.key | sudo gpg --dearmor -o /etc/apt/keyrings/deb-index.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/deb-index.gpg] https://docs.atticux.me/deb-index stable main" | sudo tee /etc/apt/sources.list.d/deb-index.list
sudo apt update
sudo apt install sing-box
```

After publication, APT can update packages with `sudo apt update && sudo apt upgrade`.
Unattended installation depends on the machine's own automatic-update configuration.

## Uninstall repository

```bash
curl -fsSL https://docs.atticux.me/deb-index/uninstall.sh | sudo bash
```

## Deployment

1. In repository **Settings → Pages → Build and deployment**, select **GitHub Actions** as Source.
   The old branch-based Pages configuration cannot deploy the new artifact workflow.
2. Keep repository secrets `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE`. The signing key must match
   `public.key`, so existing clients continue to trust the repository.
3. Run **Update APT Repository** manually, or push to `main`. It also runs daily at 00:00 UTC
   (08:00 Asia/Shanghai). The `github-pages` environment must permit deployment from `main`.

Only `pool/`, `dists/`, `public.key`, `install.sh`, `uninstall.sh` and `index.html` enter the site.
`pool/`, `dists/`, `version-lock/` and `site/` are ignored build outputs. Version locks record the
selected release; they never suppress downloading missing packages. Every configured architecture
must match exactly one asset, with the expected Debian package name and architecture.
Failures stop publication; the last successfully deployed site stays available.

Pages artifacts avoid GitHub's per-file Git limit, but Pages still has a 1 GB published-site limit.
The workflow rejects sites larger than 950,000,000 bytes to leave margin. Old binaries remain in
existing Git history; this migration does not rewrite history.

## Local build and verification

Requires Bash, authenticated `gh`, `jq`, `dpkg-dev`, `apt-utils` and GnuPG. Set `GH_TOKEN` for CI;
local builds can use `gh auth login`. Import the signing key and set `GPG_PASSPHRASE` for metadata.

```bash
mkdir -p pool dists version-lock
for config in configs/*.json; do
    bash scripts/build-repo.sh "$config"
done
bash scripts/build-repo.sh --generate-metadata
bash tests/test-build-repo.sh
```

The regression test uses synthetic DEBs, a simulated release API and a temporary GPG key.
It checks retention, missing files despite locks, failure handling, asset selection, package
validation and signed metadata. It does not verify Pages deployment or production secrets.
