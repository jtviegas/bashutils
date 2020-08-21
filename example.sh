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

usage() {
  cat <<EOM
  usage:
  $(basename $0) {
          publish
        | package_bashutils
        | prereqs [command, ...]
        }

      - package_bashutils: for the github action to make a release
      - publish: publishes to npm
      - prereqs: checks if the pre-required commands/tools are available in the system

EOM
  exit 1
}

verify

debug "1: $1 2: $2 3: $3 4: $4 5: $5 6: $6 7: $7 8: $8 9: $9"


case "$1" in
  publish)
    publish
    ;;
  package_bashutils)
    package_bashutils
    ;;
  prereqs)
    prereqs "${@:2}"
    ;;
  *)
    usage
    ;;
esac