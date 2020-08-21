# bashutils
bash scripting utils

## Notes

the script tries to include variables and secrets through the files `variables.inc` and `secrets.inc` in its folder:
```
if [ ! -f "$this_folder/variables.inc" ]; then
  warn "we DON'T have a 'variables.inc' file"
else
  . "$this_folder/variables.inc"
fi

if [ ! -f "$this_folder/secrets.inc" ]; then
  warn "we DON'T have a 'secrets.inc' file"
else
  . "$this_folder/secrets.inc"
fi
``` 

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
