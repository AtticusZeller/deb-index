# DEB Index

auto sync debs

## Supported packages

* obsidian
* sing-box
* alacritty

## Add repo

### Install

```bash
curl -fsSL https://docs.atticux.me/deb-index/install.sh | sudo bash
```

or manually

```bash
# Add GPG key
curl -fsSL https://docs.atticux.me/deb-index/public.key | sudo apt-key add -

# Add repository
echo "deb https://docs.atticux.me/deb-index stable main" | sudo tee /etc/apt/sources.list.d/deb-index.list

# Update package lists
sudo apt update
```

## Uninstall

```bash
curl -fsSL https://docs.atticux.me/deb-index/uninstall.sh | sudo bash
```

## Install package

```bash
sudo apt install obsidian
```
