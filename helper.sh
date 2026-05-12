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

# add your custom bash functions above this line

############################
#   name: pr_reviewer
#   purpose: run Copilot PR reviewer and save output to review_output.md
#   parameters: none
#   returns: 0 on success (including fallback output), 1 on setup/output validation errors
#   requires: GITHUB_TOKEN
############################
pr_reviewer(){
  info "[pr_reviewer|in]"
  local _pwd review_prompt stderr_log rc
  _pwd=$(pwd)
  stderr_log=""

  _pr_reviewer_finish() {
    local code msg
    code="$1"
    msg="[pr_reviewer|out] => ${code}"
    cd "$_pwd" || return 1
    [[ "$code" -ne 0 ]] && err "$msg" && return "$code"
    info "$msg"
  }

  if [ -z "${GITHUB_TOKEN:-}" ]; then
    err "GITHUB_TOKEN secret is required"
    _pr_reviewer_finish 1
    return $?
  fi

  cd "$this_folder" || return 1
  if ! test -f .github/agents/agent-pr-review.agent.md; then
    err "Missing agent definition: .github/agents/agent-pr-review.agent.md"
    _pr_reviewer_finish 1
    return $?
  fi

  review_prompt="Review the changes in this PR and provide feedback"
  stderr_log="$(mktemp)"

  copilot --agent agent-pr-review \
    -p "${review_prompt}" \
    --allow-all-tools \
    --no-color \
    -s > review_output.md 2>"${stderr_log}" || {
    rc=$?
    err "Copilot agent review failed with exit code ${rc}. Captured stderr:"
    if test -s "${stderr_log}"; then
      while IFS= read -r line; do
        err "$line"
      done < "${stderr_log}"
    else
      err "(stderr was empty)"
    fi
    if test -s review_output.md; then
      info "Captured stdout (last 200 lines):"
      tail -n 200 review_output.md | while IFS= read -r line; do
        info "$line"
      done
    fi
    {
      echo "⚠️ Copilot agent review failed (exit code ${rc})."
      echo
      echo "Check this workflow run logs for full details."
    } > review_output.md
    :
  }

  if ! test -s review_output.md; then
    err "Review output file is empty or unreadable (Copilot command completed but produced no review output)."
    [ -n "${stderr_log}" ] && rm -f "${stderr_log}"
    _pr_reviewer_finish 1
    return $?
  fi

  [ -n "${stderr_log}" ] && rm -f "${stderr_log}"
  _pr_reviewer_finish 0
}

# <=== MAIN SECTION END  <====

# ===> FOOTER SECTION START  ===>

usage() {
  cat <<EOM
  usage:
  $(basename "$0") { option }
    options:
      - hello_world        says hello to the world
      - build_bashutils    rebuild .bashutils by concatenating all files in sections/
      - pr_reviewer        runs Copilot PR reviewer and saves output to review_output.md
EOM
  exit 1
}

# -------------------------------------


case "$1" in
  hello_world)
    hello_world
    ;;
  build_bashutils)
    build_bashutils
    ;;
  pr_reviewer)
    pr_reviewer
    ;;
  *)
    usage
    ;;
esac

# <=== FOOTER SECTION END  <===
