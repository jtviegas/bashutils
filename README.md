# bashutils
bash scripting utils

## usage

- download it
```
curl -s https://api.github.com/repos/tgedr/bashutils/releases/latest \
| grep "browser_download_url.*utils\.tar\.bz2" \
| cut -d '"' -f 4 | wget -qi -
```
- untar it
```
tar xjpvf utils.tar.bz2
```
- use it
```
./bashutils.sh
```