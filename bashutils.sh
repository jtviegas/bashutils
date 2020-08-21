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

if [ ! -f "$this_folder/secrets.inc" ]; then
  warn "we DON'T have a 'secrets.inc' file"
else
  . "$this_folder/secrets.inc"
fi

prereqs(){
  info "[prereqs] ..."
  for arg in "$@"
  do
      debug "[prereqs] ... checking $arg"
      which "$arg" 1>/dev/null
      if [ ! "$?" -eq "0" ] ; then err "please install $arg" && return 1; fi
  done
  info "[prereqs] ...done."
}


publish(){
  info "[publish] ..."
  _pwd=`pwd`
  cd "$this_folder"
  npm config set "//${NPM_REGISTRY}/:_authToken" "${NPM_TOKEN}"
  npm publish . --access="public"
  if [ ! "$?" -eq "0" ]; then err "[publish] could not publish" && cd "$_pwd" && return 1; fi
  cd "$_pwd"
  info "[publish] ...done."
}



package_function(){
  info "[package_function] ..."
  _pwd=`pwd`
  local __r=0
  cd "$this_folder"



  cd "$_pwd"
  info "[package_function] ...done."
  return $__r
}

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