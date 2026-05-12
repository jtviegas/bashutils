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
export BASHUTILS_URL=${BASHUTILS_URL:-""}
export BASHUTILS_SHA256=${BASHUTILS_SHA256:-""}
export BASHUTILS_RELEASE_API_URL=${BASHUTILS_RELEASE_API_URL:-"https://api.github.com/repos/jtviegas/bashutils/releases/latest"}
export BASHUTILS_RELEASE_ASSET_URL=${BASHUTILS_RELEASE_ASSET_URL:-"https://github.com/jtviegas/bashutils/releases/latest/download/bashutils.tar.bz2"}
export BASHUTILS_BOOTSTRAP_URL=${BASHUTILS_BOOTSTRAP_URL:-"https://raw.githubusercontent.com/jtviegas/bashutils/bashutils-250705221643/.bashutils"}
export BASHUTILS_BOOTSTRAP_SHA256=${BASHUTILS_BOOTSTRAP_SHA256:-"9cea725169e1e0931002a9bf474746ad25a85799319b48577c266bb77f327d1d"}
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
  local now_epoch
  local last_check_epoch
  local elapsed
  local did_remote_check=0
  local bashutils_tmp
  local bashutils_archive_tmp
  local actual_sha256
  local expected_sha256
  local download_url
  local release_json
  local asset_name

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
            return 0
          fi
          ;;
      esac
    fi
  fi

  if ! command -v curl >/dev/null 2>&1; then
    err "[download_bashutils_if_newer] please install curl"
    return 1
  fi

  bashutils_tmp="$(mktemp)"
  if [ -n "$BASHUTILS_URL" ] && [ -n "$BASHUTILS_SHA256" ]; then
    download_url="$BASHUTILS_URL"
    expected_sha256="$BASHUTILS_SHA256"
    if [ ! -f "$bashutils" ]; then
      if ! curl -fsSL -R "$download_url" -o "$bashutils_tmp"; then
        err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE"
        rm -f "$bashutils_tmp"
        return 1
      fi
    else
      if ! curl -fsSL -R -z "$bashutils" "$download_url" -o "$bashutils_tmp"; then
        err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE"
        rm -f "$bashutils_tmp"
        return 1
      fi
    fi
  else
    asset_name="$(basename "$BASHUTILS_RELEASE_ASSET_URL")"
    release_json="$(curl -fsSL -H "User-Agent: bashutils-template" "$BASHUTILS_RELEASE_API_URL" 2>/dev/null)"
    if command -v jq >/dev/null 2>&1; then
      expected_sha256="$(printf '%s' "$release_json" | jq -r --arg asset_name "$asset_name" '.assets[] | select(.name == $asset_name) | .digest' 2>/dev/null | sed -n 's/^sha256:\([a-f0-9]\{64\}\)$/\1/p' | head -n 1)"
    else
      expected_sha256="$(printf '%s' "$release_json" | tr '{' '\n' | grep "\"name\":\"$asset_name\"" | sed -n 's/.*"digest":"sha256:\([a-f0-9]\{64\}\)".*/\1/p' | head -n 1)"
    fi
    if [ -n "$expected_sha256" ]; then
      if ! command -v tar >/dev/null 2>&1; then
        err "[download_bashutils_if_newer] please install tar with bzip2 support"
        rm -f "$bashutils_tmp"
        return 1
      fi
      bashutils_archive_tmp="$(mktemp)"
      if ! curl -fsSL -R "$BASHUTILS_RELEASE_ASSET_URL" -o "$bashutils_archive_tmp"; then
        err "[download_bashutils_if_newer] failed to download latest release asset"
        rm -f "$bashutils_tmp" "$bashutils_archive_tmp"
        return 1
      fi
      if command -v sha256sum >/dev/null 2>&1; then
        actual_sha256="$(sha256sum "$bashutils_archive_tmp" | awk '{print $1}')"
      elif command -v shasum >/dev/null 2>&1; then
        actual_sha256="$(shasum -a 256 "$bashutils_archive_tmp" | awk '{print $1}')"
      else
        err "[download_bashutils_if_newer] please install sha256sum or shasum to verify release asset"
        rm -f "$bashutils_tmp" "$bashutils_archive_tmp"
        return 1
      fi
      if [ "$actual_sha256" != "$expected_sha256" ]; then
        err "[download_bashutils_if_newer] checksum verification failed for release asset"
        rm -f "$bashutils_tmp" "$bashutils_archive_tmp"
        return 1
      fi
      if ! tar -xjf "$bashutils_archive_tmp" "$INCLUDE_FILE" -O > "$bashutils_tmp"; then
        err "[download_bashutils_if_newer] failed to extract $INCLUDE_FILE from release asset (archive may be corrupted or tar lacks bzip2 support)"
        rm -f "$bashutils_tmp" "$bashutils_archive_tmp"
        return 1
      fi
      rm -f "$bashutils_archive_tmp"
    else
      warn "[download_bashutils_if_newer] failed to resolve latest release checksum (API unavailable or malformed response), using bootstrap artifact"
      download_url="$BASHUTILS_BOOTSTRAP_URL"
      expected_sha256="$BASHUTILS_BOOTSTRAP_SHA256"
      if [ -z "$expected_sha256" ]; then
        err "[download_bashutils_if_newer] expected checksum is empty for bootstrap $INCLUDE_FILE"
        rm -f "$bashutils_tmp"
        return 1
      fi
      if [ ! -f "$bashutils" ]; then
        if ! curl -fsSL -R "$download_url" -o "$bashutils_tmp"; then
          err "[download_bashutils_if_newer] failed to download bootstrap $INCLUDE_FILE"
          rm -f "$bashutils_tmp"
          return 1
        fi
      else
        if ! curl -fsSL -R -z "$bashutils" "$download_url" -o "$bashutils_tmp"; then
          err "[download_bashutils_if_newer] failed to download bootstrap $INCLUDE_FILE"
          rm -f "$bashutils_tmp"
          return 1
        fi
      fi
    fi
  fi
  did_remote_check=1

  if [ -s "$bashutils_tmp" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual_sha256="$(sha256sum "$bashutils_tmp" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      actual_sha256="$(shasum -a 256 "$bashutils_tmp" | awk '{print $1}')"
    else
      err "[download_bashutils_if_newer] please install sha256sum or shasum to verify $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi

    if [ -z "$expected_sha256" ]; then
      err "[download_bashutils_if_newer] expected checksum is empty for $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi

    if [ "$actual_sha256" != "$expected_sha256" ]; then
      err "[download_bashutils_if_newer] checksum verification failed for $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi

    if ! mv "$bashutils_tmp" "$bashutils"; then
      err "[download_bashutils_if_newer] failed to replace $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi
    info "[download_bashutils_if_newer] updated $INCLUDE_FILE"
  else
    rm -f "$bashutils_tmp"
  fi

  if [ "$did_remote_check" -eq 1 ]; then
    touch "$bashutils_last_check" || warn "[download_bashutils_if_newer] failed to update last check marker; next run will perform a remote check"
  fi
}

# -------------------------------
# --- source variables files
source_if_exists "$this_folder/$FILE_VARIABLES"
source_if_exists "$this_folder/$FILE_LOCAL_VARIABLES"
source_if_exists "$this_folder/$FILE_SECRETS"

# ---------- include bashutils ----------
download_bashutils_if_newer || exit 1
. "$this_folder/$INCLUDE_FILE"

# <=== HEADER SECTION END  <===

# ===> MAIN SECTION START  ===>

hello_world(){
  info "[hello_world|in]"
  local _pwd
  _pwd=$(pwd)
  cd "$this_folder"

  echo "hello world"
  local result="$?"

  cd "$_pwd"
  local msg="[hello_world|out] => ${result}"
  [[ "$result" -ne 0 ]] && err "$msg" && exit 1
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
