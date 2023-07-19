#!/usr/bin/env bash

# http://bash.cumulonim.biz/NullGlob.html
shopt -s nullglob

if [ -z "$this_folder" ]; then
  this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  if [ -z "$this_folder" ]; then
    this_folder=$(dirname $(readlink -f $0))
  fi
fi
parent_folder=$(dirname "$this_folder")

# --- START include bashutils SECTION ---
_pwd=$(pwd)
cd "$this_folder"
curl -s https://api.github.com/repos/tgedr/bashutils/releases/latest \
| grep "browser_download_url.*utils\.tar\.bz2" \
| cut -d '"' -f 4 | wget -qi -
tar xjpvf utils.tar.bz2
rm utils.tar.bz2
. "$this_folder/bashutils.inc"
cd "$_pwd"
# --- END include bashutils SECTION ---

update_bashutils(){
  echo "[update_bashutils] ..."

  _pwd=`pwd`
  cd "$this_folder"

  curl -s https://api.github.com/repos/tgedr/bashutils/releases/latest \
  | grep "browser_download_url.*utils\.tar\.bz2" \
  | cut -d '"' -f 4 | wget -qi -
  tar xjpvf utils.tar.bz2
  if [ ! "$?" -eq "0" ] ; then echo "[update_bashutils] could not untar it" && cd "$_pwd" && return 1; fi
  rm utils.tar.bz2

  cd "$_pwd"
  echo "[update_bashutils] ...done."
}

usage() {
  cat <<EOM
  usage:
  $(basename $0) {
          update_bashutils
        }

      - update_bashutils: updates the lib

EOM
  exit 1
}


debug "1: $1 2: $2 3: $3 4: $4 5: $5 6: $6 7: $7 8: $8 9: $9"


case "$1" in
  update_bashutils)
    update_bashutils
    ;;
  *)
    usage
    ;;
esac