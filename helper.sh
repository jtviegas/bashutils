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
    echo " [DEBUG] $(date) ... $__msg "
}

info(){
    local __msg="$1"
    echo " [INFO]  $(date) ->>> $__msg "
}

warn(){
    local __msg="$1"
    echo " [WARN]  $(date) *** $__msg "
}

err(){
    local __msg="$1"
    echo " [ERR]   $(date) !!! $__msg "
}

source_if_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    warn "we DON'T have a $(basename "$file") file - creating it"
    touch "$file"
    chmod 600 "$file"
  else
    . "$file"
  fi
}

# ---------- CONSTANTS ----------
export FILE_VARIABLES=${FILE_VARIABLES:-".variables"}
export FILE_LOCAL_VARIABLES=${FILE_LOCAL_VARIABLES:-".local_variables"}
export FILE_SECRETS=${FILE_SECRETS:-".secrets"}
export INCLUDE_FILE=${INCLUDE_FILE:-".bashutils"}
export BASHUTILS_URL=${BASHUTILS_URL:-"https://api.github.com/repos/jtviegas/bashutils/contents/.bashutils"}
export BASHUTILS_CHECKSUM_URL=${BASHUTILS_CHECKSUM_URL:-"https://api.github.com/repos/jtviegas/bashutils/contents/.bashutils.checksum"}
export BASHUTILS_CHECK_INTERVAL_SECONDS=${BASHUTILS_CHECK_INTERVAL_SECONDS:-"86400"}

get_file_mtime_epoch() {
  local file="$1"
  local mtime
  mtime="$(stat -c %Y "$file" 2>/dev/null)" && {
    echo "$mtime"
    return 0
  }
  mtime="$(stat -f %m "$file" 2>/dev/null)" && {
    echo "$mtime"
    return 0
  }
  return 1
}

download_bashutils_if_newer() {
  local bashutils="$this_folder/$INCLUDE_FILE"
  local bashutils_last_check="$this_folder/${INCLUDE_FILE}.last_check"
  local bashutils_checksum="$this_folder/${INCLUDE_FILE}.checksum"
  local just_fetch="0"
  local now_epoch
  local last_check_epoch
  local elapsed
  local did_remote_check=0
  local bashutils_tmp
  local checksum_tmp
  local actual_sha256
  local expected_sha256

  
  if [ -f "$bashutils" ] && [ -f "$bashutils_last_check" ]; then
    now_epoch=$(date +%s)
    if last_check_epoch="$(get_file_mtime_epoch "$bashutils_last_check")"; then
      case "$last_check_epoch" in
        ''|*[!0-9]*)
          warn "[download_bashutils_if_newer] invalid last check marker timestamp, forcing a remote check"
          ;;
        *)
          elapsed=$((now_epoch - last_check_epoch))
          if [ "$elapsed" -lt "$BASHUTILS_CHECK_INTERVAL_SECONDS" ]; then
            info "[download_bashutils_if_newer] no need to update $INCLUDE_FILE (last checked $elapsed seconds ago)"
            return 0
          fi
          ;;
      esac
    fi
  else
    info "[download_bashutils_if_newer] no $INCLUDE_FILE or ${INCLUDE_FILE}.last_check found - we will fetch it"
    just_fetch="1"
  fi

  if ! command -v curl >/dev/null 2>&1; then
    err "[download_bashutils_if_newer] please install curl"
    return 1
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    err "[download_bashutils_if_newer] please install sha256sum to verify $INCLUDE_FILE"
    return 1
  fi

  checksum_tmp="$(mktemp)"
  if ! curl -fsSL "$BASHUTILS_CHECKSUM_URL" \
    | python3 -c "import sys,json,base64; sys.stdout.buffer.write(base64.b64decode(json.load(sys.stdin)['content']))" \
    > "$checksum_tmp"; then
    err "[download_bashutils_if_newer] failed to download $(basename "$BASHUTILS_CHECKSUM_URL")"
    rm -f "$checksum_tmp"
    return 1
  fi
  expected_sha256=$(cat "$checksum_tmp" | awk '{print $1}')
  info "[download_bashutils_if_newer] expected_sha256: $expected_sha256"
  rm -f "$checksum_tmp"

  if [ "$just_fetch" -ne "1" ]; then
      info "[download_bashutils_if_newer] checking existing $INCLUDE_FILE"

      actual_sha256=$(cat "$bashutils_checksum" | awk '{print $1}')
      info "[download_bashutils_if_newer] actual_sha256: $actual_sha256"
      
      if [ "$actual_sha256" != "$expected_sha256" ]; then
        info "[download_bashutils_if_newer] $INCLUDE_FILE is outdated (actual: $actual_sha256, expected: $expected_sha256), updating it"
        just_fetch="1"
      else
        info "[download_bashutils_if_newer] $INCLUDE_FILE is up to date"
      fi
  fi


  if [ "$just_fetch" -eq "1" ]; then
    bashutils_tmp="$(mktemp)"
    curl -fsSL "$BASHUTILS_URL" \
      | python3 -c "import sys,json,base64; sys.stdout.buffer.write(base64.b64decode(json.load(sys.stdin)['content']))" \
      > "$bashutils_tmp"
    if [ ! "$?" -eq "0" ]; then
      err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi
    info "[download_bashutils_if_newer] downloaded $INCLUDE_FILE to $bashutils_tmp"
    actual_sha256="$(sha256sum "$bashutils_tmp" | awk '{print $1}')"
    info "[download_bashutils_if_newer] actual_sha256: $actual_sha256"

    if [ "$actual_sha256" != "$expected_sha256" ]; then
      info "[download_bashutils_if_newer] $INCLUDE_FILE checksum is not equal to the expected one (actual: $actual_sha256, expected: $expected_sha256), aborting update"
      return 1
    fi

    mv "$bashutils_tmp" "$bashutils"
    rm -f "$bashutils_tmp"
    touch "$bashutils_last_check" || warn "[download_bashutils_if_newer] failed to update last check marker; next run will perform a remote check"
    info "[download_bashutils_if_newer] updated $INCLUDE_FILE or ${INCLUDE_FILE}.last_check "
  fi

}

# -------------------------------
# --- source variables files
source_if_exists "$this_folder/$FILE_VARIABLES"
source_if_exists "$this_folder/$FILE_LOCAL_VARIABLES"
source_if_exists "$this_folder/$FILE_SECRETS"


# <=== HEADER SECTION END  <===

# ===> MAIN SECTION START  ===>

reqs(){
  info "[reqs|in]"
  _pwd=`pwd`
  cd "$this_folder"

  sudo apt-get update && sudo apt-get install -y bats
  local result="$?"

  cd "$_pwd"
  local msg="[reqs|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

test(){
  info "[test|in]"
  _pwd=`pwd`
  cd "$this_folder"

  bats test
  local result="$?"

  cd "$_pwd"
  local msg="[test|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

build_bashutils(){
  info "[build_bashutils|in]"
  local sections_dir="$this_folder/sections"
  local out_file="$this_folder/$INCLUDE_FILE"
  local _pwd
  local checksum_result
  _pwd=$(pwd)

  [ ! -d "$sections_dir" ] && err "[build_bashutils] sections folder not found: $sections_dir" && return 1

  local files
  files=("$sections_dir"/*.sh)
  [ ${#files[@]} -eq 0 ] && err "[build_bashutils] no .sh files found in $sections_dir" && return 1

  > "$out_file"
  for f in "${files[@]}"; do
    cat "$f" >> "$out_file" || return 1
    echo >> "$out_file" || return 1
  done

  if command -v sha256sum >/dev/null 2>&1; then
    cd "$this_folder" || return 1
    sha256sum "$INCLUDE_FILE" > "${INCLUDE_FILE}.checksum"
    checksum_result="$?"
    cd "$_pwd" || return 1
    if [ "$checksum_result" -ne 0 ]; then
      return 1
    fi
  else
    err "[build_bashutils] please install sha256sum to generate checksum file"
    return 1
  fi

  info "[build_bashutils|out] => 0"
}


# add your custom bash functions above this line

# <=== MAIN SECTION END  <====

# ===> FOOTER SECTION START  ===>

usage() {
  cat <<EOM
  usage:
  $(basename "$0") { option }
    options:
      - reqs               installs required tools and dependencies
      - test               runs tests
      - build_bashutils    rebuild .bashutils by concatenating all files in sections/
EOM
  exit 1
}

# -------------------------------------


case "$1" in
  reqs)
    reqs
    ;;
  test)
    test
    ;;
  build_bashutils)
    build_bashutils
    ;;
  download_bashutils_if_newer)
    download_bashutils_if_newer
    ;;
  *)
    usage
    ;;
esac

# <=== FOOTER SECTION END  <===
