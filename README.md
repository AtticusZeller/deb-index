# DEB Index

auto sync debs 

## Supported packages

- Clash Verge Rev

## Add repo

```bash
echo "deb [trusted=yes] https://atticuszeller.github.io/deb-index stable main" | \
    sudo tee /etc/apt/sources.list.d/atticuszeller-deb-index.list
```
## Intsall package
```bash
sudo apt update
sudo apt install clash-verge-rev
```

