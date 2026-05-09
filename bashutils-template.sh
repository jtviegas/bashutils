#!/usr/bin/env bash

# ===> HEADER SECTION START  ===>

# http://bash.cumulonim.biz/NullGlob.html
shopt -s nullglob
# -------------------------------
this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ -z "$this_folder" ]; then
  this_folder=$(dirname "$(readlink -f "$0")")
fi

# -------------------------------
# --- required functions
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

source_if_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    warn "we DON'T have a $(basename "$file") file - creating it"
    touch "$file"
  else
    . "$file"
  fi
}

download_bashutils_if_newer() {
  local bashutils="$this_folder/$INCLUDE_FILE"
  local bashutils_tmp="${bashutils}.tmp"

  if ! command -v curl >/dev/null 2>&1; then
    err "[download_bashutils_if_newer] please install curl"
    return 1
  fi

  if [ ! -f "$bashutils" ]; then
    curl -fsSL -R "$BASHUTILS_URL" -o "$bashutils_tmp"
  else
    curl -fsSL -R -z "$bashutils" "$BASHUTILS_URL" -o "$bashutils_tmp"
  fi
  result="$?"
  [ "$result" -ne "0" ] && err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE" && rm -f "$bashutils_tmp" && return 1

  if [ -s "$bashutils_tmp" ]; then
    mv "$bashutils_tmp" "$bashutils"
    result="$?"
    [ "$result" -ne "0" ] && err "[download_bashutils_if_newer] failed to replace $INCLUDE_FILE" && rm -f "$bashutils_tmp" && return 1
    info "[download_bashutils_if_newer] updated $INCLUDE_FILE"
  else
    rm -f "$bashutils_tmp"
  fi
}

# ---------- CONSTANTS ----------
export FILE_VARIABLES=${FILE_VARIABLES:-".variables"}
export FILE_LOCAL_VARIABLES=${FILE_LOCAL_VARIABLES:-".local_variables"}
export FILE_SECRETS=${FILE_SECRETS:-".secrets"}
export INCLUDE_FILE=${INCLUDE_FILE:-".bashutils"}

# -------------------------------
# --- source variables files
source_if_exists "$this_folder/$FILE_VARIABLES"
source_if_exists "$this_folder/$FILE_LOCAL_VARIABLES"
source_if_exists "$this_folder/$FILE_SECRETS"

# ---------- include bashutils ----------
BASHUTILS_URL=${BASHUTILS_URL:-"https://raw.githubusercontent.com/jtviegas/bashutils/master/.bashutils"}
download_bashutils_if_newer || exit 1
. "$this_folder/$INCLUDE_FILE"

# <=== HEADER SECTION END  <===

# ===> MAIN SECTION START  ===>

hello_world(){
  info "[hello_world|in]"
  _pwd=`pwd`
  cd "$this_folder"

  echo "hello world"
  local result="$?"

  cd "$_pwd"
  local msg="[hello_world|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

# add your custom bash functions above this line

# <=== MAIN SECTION END  <===

# ===> FOOTER SECTION START  ===>

usage() {
  cat <<EOM
  usage:
  $(basename "$0") { option }
    options:
      - hello_world        says hello to the world
EOM
  exit 1
}

# -------------------------------------

case "$1" in
  hello_world)
    hello_world
    ;;
  *)
    usage
    ;;
esac

# <=== FOOTER SECTION END  <===
