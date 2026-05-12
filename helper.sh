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
export BASHUTILS_URL=${BASHUTILS_URL:-"https://raw.githubusercontent.com/jtviegas/bashutils/master/.bashutils"}
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

  if [ ! -f "$bashutils" ]; then
    if ! curl -fsSL -R "$BASHUTILS_URL" -o "$bashutils_tmp"; then
      err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi
  else
    if ! curl -fsSL -R -z "$bashutils" "$BASHUTILS_URL" -o "$bashutils_tmp"; then
      err "[download_bashutils_if_newer] failed to download $INCLUDE_FILE"
      rm -f "$bashutils_tmp"
      return 1
    fi
  fi
  did_remote_check=1

  if [ -s "$bashutils_tmp" ]; then
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

reqs(){
  info "[reqs|in]"
  _pwd=`pwd`
  cd "$this_folder"

  local result="0"

  which copilot > /dev/null 2>&1
  if [ ! "$?" -eq "0" ] ; then
    info "[reqs] installing copilot ..."
    npm install -g @github/copilot
    result="$?"
  fi

  which bats > /dev/null 2>&1
  if [ ! "$?" -eq "0" ] ; then
    info "[reqs] installing bats ..."
    sudo apt-get install -y bats
    result="$?"
  fi

  cd "$_pwd"
  local msg="[reqs|out] => ${result}"
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
  elif command -v shasum >/dev/null 2>&1; then
    cd "$this_folder" || return 1
    shasum -a 256 "$INCLUDE_FILE" > "${INCLUDE_FILE}.checksum"
    checksum_result="$?"
    cd "$_pwd" || return 1
    if [ "$checksum_result" -ne 0 ]; then
      return 1
    fi
  else
    err "[build_bashutils] please install sha256sum or shasum to generate checksum file"
    return 1
  fi

  info "[build_bashutils|out] => 0"
}

prompt_copilot_agent(){
  info "[get_pr_review_from_agent|in]"
  _pwd=`pwd`
  cd "$this_folder"

  local result="0"

  review_prompt="Review the changes in this PR and provide feedback"
  stderr_log="$(mktemp)"

  copilot --agent code-review \
    -p "${review_prompt}" \
    --allow-all-tools \
    --no-color
  #  -s > review_output.md 2>"${stderr_log}"
  result="$?"
  "cat review_output.md
  

  cd "$_pwd"
  local msg="[get_pr_review_from_agent|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
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
      - build_bashutils    rebuild .bashutils by concatenating all files in sections/
      - prompt_copilot_agent   prompts the copilot agent with a review request and outputs the response
EOM
  exit 1
}

# -------------------------------------


case "$1" in
  reqs)
    reqs
    ;;
  build_bashutils)
    build_bashutils
    ;;
  prompt_copilot_agent)
    prompt_copilot_agent
    ;;
  *)
    usage
    ;;
esac

# <=== FOOTER SECTION END  <===
