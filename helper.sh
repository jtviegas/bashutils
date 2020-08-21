#!/usr/bin/env bash

# http://bash.cumulonim.biz/NullGlob.html
shopt -s nullglob

this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ -z "$this_folder" ]; then
  this_folder=$(dirname $(readlink -f $0))
fi
parent_folder=$(dirname "$this_folder")

debug(){
    local __msg="$1"
    echo " [DEBUG] `date` ... $__msg "
}

info(){
    local __msg="$1"
    echo " [INFO]  `date` ->>> $__msg "
}

warn(){
    local __msg="$1"
    echo " [WARN]  `date` *** $__msg "
}

err(){
    local __msg="$1"
    echo " [ERR]   `date` !!! $__msg "
}

if [ ! -f "$this_folder/variables.inc" ]; then
  warn "we DON'T have a 'variables.inc' file"
else
  . "$this_folder/variables.inc"
fi


package(){
  info "[package] ..."
  _pwd=`pwd`
  cd "$this_folder"

  tar cpvf $TAR_NAME $MAIN_SCRIPT
  if [ ! "$?" -eq "0" ] ; then err "[package] could not tar it" && cd "$_pwd" && return 1; fi

  cd "$_pwd"
  info "[package] ...done."
}

usage() {
  cat <<EOM
  usage:
  $(basename $0) { package }

      - package: packages the utils to a tar

EOM
  exit 1
}

debug "1: $1 2: $2 3: $3 4: $4 5: $5 6: $6 7: $7 8: $8 9: $9"


case "$1" in
  package)
    package
    ;;
  *)
    usage
    ;;
esac