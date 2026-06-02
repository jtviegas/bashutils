##########################################
#######    ------- bash -------    #######
##########################################

############################
#   name: contains
#   purpose: checks whether a space-separated list contains a specific item
#   parameters: $1 (space-separated list), $2 (item to search for)
#   returns: 0 if found, 1 if not found
############################
# contains <list> <item>
# echo $? # 0： match, 1: failed
contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1
}

############################
#   name: verify_prereqs
#   purpose: verifies that all required commands are available on PATH; exits early with an error message for the first missing one
#   parameters: $@ (one or more command names to check with 'which')
#   returns: 0 if all commands found, 1 on first missing command
############################
verify_prereqs(){
  info "[verify_prereqs] ..."
  for arg in "$@"
  do
      debug "[verify_prereqs] ... checking $arg"
      which "$arg" 1>/dev/null
      if [ ! "$?" -eq "0" ] ; then err "[verify_prereqs] please install $arg" && return 1; fi
  done
  info "[verify_prereqs] ...done."
}

############################
#   name: verify_env
#   purpose: verifies that all required environment variable names are provided as non-empty arguments
#   parameters: $@ (one or more environment variable names to verify are non-empty)
#   returns: 0 if all names are non-empty, 1 on first empty name
############################
verify_env(){
  info "[verify_env] ..."
  for arg in "$@"
  do
      debug "[verify_env] ... checking $arg"
      if [ -z "${!arg}" ]; then err "[verify_env] please define env var: $arg" && exit 1; fi
  done
  info "[verify_env] ...done."
}

############################
#   name: package
#   purpose: creates a bzip2-compressed tar archive from the project root
#   parameters: none
#   requires: TAR_NAME (output archive path), INCLUDE_FILE (file/folder to archive), this_folder (project root)
############################
package(){
  info "[package] ..."
  _pwd=`pwd`
  cd "$this_folder"

  tar cjpvf "$TAR_NAME" "$INCLUDE_FILE"
  if [ ! "$?" -eq "0" ] ; then err "[package] could not tar it" && cd "$_pwd" && return 1; fi

  cd "$_pwd"
  info "[package] ...done."
}

############################
#   name: create_from_template_and_envvars
#   purpose: renders a template file by substituting named environment variables using sed, writing the result to a destination file
#   parameters: $1 (template file path), $2 (destination file path), $3+ (names of environment variables to substitute)
#   returns: 0 on success, 1 if fewer than 3 arguments are provided or sed fails
############################
create_from_template_and_envvars() {
  info "[create_from_template_and_envvars] ...( $@ )"
  local usage_msg=$'create_from_template_and_envvars: creates a file from a template substituting env vars:\nusage:\n    create_from_template_and_envvars TEMPLATE DESTINATION [ENVVARS...]'

  if [ -z "$3" ] ; then echo "$usage_msg" && return 1; fi

  local template="$1"
  local destination="$2"
  local vars="${@:3}"

  local expression=""
  for var in $vars
  do
    eval val=\${"$var"}
    #echo "$var: $val"
    expression="${expression}s/${var}/${val}/g;"
  done

  #echo "expression: $expression"
  sed "${expression}" "$template" > "$destination"
  if [ ! "$?" -eq "0" ]; then err "[create_from_template_and_envvars] sed command was not successful" && return 1; fi
  info "[create_from_template_and_envvars] ...done."
}

############################
#   name: add_entry_to_file
#   purpose: upserts an 'export VAR=VALUE' entry in a file relative to this_folder;
#            removes any existing line for the variable before appending the new value;
#            if $3 is empty the variable entry is deleted without replacement
#   parameters: $1 (file name, relative to this_folder), $2 (variable name), $3 (variable value, optional)
#   requires: this_folder (project root)
############################
add_entry_to_file()
{
  info "[add_entry_to_file|in] ($1, $2, ${3:0:5})"
  [ -z "$2" ] && err "no parameters provided" && return 1
  local file="$1"
  local file_path="${this_folder}/${file}"
  local var_name="$2"
  local var_value="$3"

  if [ -f "$file_path" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "/export $var_name=/d" "$file_path"
    else
      sed -i "/$var_name=/c\\" "$file_path"
    fi

    if [ ! -z "$var_value" ]; then
      echo "export $var_name=$var_value" | tee -a "$file_path" > /dev/null
    fi
  fi
  info "[add_entry_to_file|out]"
}

############################
#   name: add_entry_to_variables
#   purpose: upserts an environment variable entry in the shared variables file (FILE_VARIABLES)
#   parameters: $1 (variable name), $2 (variable value, optional — omit to delete the entry)
#   requires: FILE_VARIABLES
############################
add_entry_to_variables()
{
  info "[add_entry_to_variables|in] ($1, $2)"
  [ -z "$1" ] && err "no parameters provided" && return 1

  target_file="${FILE_VARIABLES}"
  add_entry_to_file "$target_file" "$1" "$2" 

  info "[add_entry_to_variables|out]"
}

############################
#   name: add_entry_to_local_variables
#   purpose: upserts an environment variable entry in the local variables file (FILE_LOCAL_VARIABLES)
#   parameters: $1 (variable name), $2 (variable value, optional — omit to delete the entry)
#   requires: FILE_LOCAL_VARIABLES
############################
add_entry_to_local_variables()
{
  info "[add_entry_to_local_variables|in] ($1, $2)"
  [ -z "$1" ] && err "no parameters provided" && return 1

  target_file="${FILE_LOCAL_VARIABLES}"
  add_entry_to_file "$target_file" "$1" "$2" 

  info "[add_entry_to_local_variables|out]"
}

############################
#   name: add_entry_to_secrets
#   purpose: upserts an environment variable entry in the secrets file (FILE_SECRETS)
#   parameters: $1 (variable name), $2 (secret value, optional — omit to delete the entry)
#   requires: FILE_SECRETS
############################
add_entry_to_secrets()
{
  info "[add_entry_to_secrets|in] ($1, ${2:0:7})"
  [ -z "$1" ] && err "no parameters provided" && return 1

  target_file="${FILE_SECRETS}"
  add_entry_to_file "$target_file" "$1" "$2" 

  info "[add_entry_to_secrets|out]"
}

############################
#   name: git_tag_and_push
#   purpose: creates an annotated git tag on a specific commit and pushes all tags to the remote
#   parameters: $1 (version tag, e.g. v1.2.3), $2 (commit hash to tag)
#   returns: exits 1 if tag creation or push fails
############################
git_tag_and_push()
{
  info "[git_tag_and_push|in] ($1, ${2:0:7})"

  [ -z "$1" ] && err "must provide parameter VERSION" && exit 1
  local VERSION="$1"
  [ -z "$2" ] && err "must provide parameter COMMIT_HASH" && exit 1
  local COMMIT_HASH="$2"

  git tag -a "$VERSION" "$COMMIT_HASH" -m "release $VERSION" && git push --tags
  result="$?"
  [ "$result" -ne "0" ] && err "[git_tag_and_push|out] could not tag and push" && exit 1

  info "[git_tag_and_push|out] => ${result}"
}


############################
#   name: git_tag_and_push_auto_uv
#   purpose: reads the project version from pyproject.toml via uv, then creates an annotated git tag on the latest commit and pushes all tags to remote
#   parameters: none
#   requires: uv (with tomllib), git, this_folder
############################
git_tag_and_push_auto_uv()
{
  info "[git_tag_and_push_auto_uv|in]"

  local version=$(uv run python -c "import tomllib; d=tomllib.load(open('pyproject.toml','rb')); print(d['project']['version'])")
  local commit_hash=$(git log -1 --format="%H")
  info "[git_tag_and_push_auto_uv] version: $version, commit_hash: $commit_hash"

  git tag -a "$version" "$commit_hash" -m "release $version" && git push --tags
  result="$?"
  
  [ "$result" -ne "0" ] && err "[git_tag_and_push|out] could not tag and push" && exit 1

  info "[git_tag_and_push_auto_uv|out] => ${result}"
}

############################
#   name: get_latest_tag
#   purpose: retrieves the latest git tag from the repository
#   parameters: none
############################
get_latest_tag() {
  info "[get_latest_tag|in]" >&2
  git fetch --tags > /dev/null 2>&1
  local latest_tag
  latest_tag="$(git describe --tags --abbrev=0 2>/dev/null)"
  if [ -z "$latest_tag" ]; then
    err "[get_latest_tag|out] => 1 (no tags found)" >&2
    exit 1
  fi

  echo "$latest_tag"
  info "[get_latest_tag|out] => ${latest_tag}" >&2
  return 0
}

############################
#   name: changelog
#   purpose: generates a CHANGELOG file from git log (format: hash, date, refs, subject)
#   parameters: $1 (output filename, default: CHANGELOG)
#   requires: this_folder (project root)
############################

changelog(){
  info "[changelog|in] ($1)"

  local FILE="CHANGELOG"
  [ ! -z $1 ] && FILE="$1"
  info "[changelog] creating file: $FILE"

  _pwd=`pwd`
  cd "$this_folder"

  git log --pretty=format:"- %h %as %d %s" > "$FILE"
  result="$?"

  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[changelog|out]  => ${result}" && exit 1
  echo "[changelog|out] => $result"
}

############################
#   name: proj_code_transfer
#   purpose: copies source folders to a staging directory while rewriting file paths and Python import statements;
#            skips files whose path contains '__' (e.g. __pycache__)
#   parameters: $1 (staging/tmp output folder)
#               $2 (space-separated list of source folders to copy)
#               $3 (path segment to replace in destination paths — origin)
#               $4 (path segment replacement — target)
#               $5 (import prefix to replace — origin, e.g. 'old_pkg.')
#               $6 (import prefix replacement — target, e.g. 'new_pkg.')
#   requires: this_folder (project root)
############################

proj_code_transfer(){
  info "[proj_code_transfer|in] ($1)"

  # example:
  # export CODE_TRANSFER_FOLDERS="src tests"
  # export CODE_TRANSFER_PATH_REPLACEMENT_ORIGIN="ssds_qsd_dataops"
  # export CODE_TRANSFER_PATH_REPLACEMENT_TARGET="tgedr/dataops"

  # export CODE_TRANSFER_IMPORT_REPLACEMENT_ORIGIN="ssds_qsd_dataops."
  # export CODE_TRANSFER_IMPORT_REPLACEMENT_TARGET="tgedr.dataops."

  [ -z $1 ] && err "[proj_code_transfer] missing argument TMP_FOLDER" && exit 1
  local TMP_FOLDER="$1"
  [ -z $2 ] && err "[proj_code_transfer] missing argument CODE_TRANSFER_FOLDERS" && exit 1
  local CODE_TRANSFER_FOLDERS="$2"
  [ -z $3 ] && err "[proj_code_transfer] missing argument CODE_TRANSFER_PATH_REPLACEMENT_ORIGIN" && exit 1
  local CODE_TRANSFER_PATH_REPLACEMENT_ORIGIN="$3"
  [ -z $4 ] && err "[proj_code_transfer] missing argument CODE_TRANSFER_PATH_REPLACEMENT_TARGET" && exit 1
  local CODE_TRANSFER_PATH_REPLACEMENT_TARGET="$4"
  [ -z $5 ] && err "[proj_code_transfer] missing argument CODE_TRANSFER_IMPORT_REPLACEMENT_ORIGIN" && exit 1
  local CODE_TRANSFER_IMPORT_REPLACEMENT_ORIGIN="$5"
  [ -z $6 ] && err "[proj_code_transfer] missing argument CODE_TRANSFER_IMPORT_REPLACEMENT_TARGET" && exit 1
  local CODE_TRANSFER_IMPORT_REPLACEMENT_TARGET="$6"

   _pwd=`pwd`
  cd "$this_folder"

  [[ ! -d "$TMP_FOLDER" ]] && mkdir -p "$TMP_FOLDER"

  for item in "${CODE_TRANSFER_FOLDERS[@]}"; do
    info "[proj_code_transfer] checking: $item"
    find ./$item -type f | while read -r filepath; do

    if [[ "$filepath" != *"__"* ]]; then
        info "[proj_code_transfer] file: $filepath"
        new_filepath=${filepath//$CODE_TRANSFER_PATH_REPLACEMENT_ORIGIN/$CODE_TRANSFER_PATH_REPLACEMENT_TARGET}
        info "[proj_code_transfer] copying it to: $TMP_FOLDER/$new_filepath"
        mkdir -p "$(dirname $TMP_FOLDER/$new_filepath)"
        cp "$filepath" "$TMP_FOLDER/$new_filepath"
        sed -i "" "s/import $CODE_TRANSFER_IMPORT_REPLACEMENT_ORIGIN/import $CODE_TRANSFER_IMPORT_REPLACEMENT_TARGET/g" "$TMP_FOLDER/$new_filepath"
        sed -i "" "s/from $CODE_TRANSFER_IMPORT_REPLACEMENT_ORIGIN/from $CODE_TRANSFER_IMPORT_REPLACEMENT_TARGET/g" "$TMP_FOLDER/$new_filepath"
    fi
    done
  done

  local result="$?"
  cd "$_pwd"
  local msg="[proj_code_transfer|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: add_pypi_config
#   purpose: creates ~/.pypirc with a token-based PyPI auth entry if the file does not already exist
#   parameters: $1 (PyPI API token)
############################

add_pypi_config(){
  info "[add_pypi_config] ..."

  [ -z $1 ] && err "[add_pypi_config] missing argument PYPI_TOKEN" && exit 1
  local PYPI_TOKEN="$1"
  
  _pwd=`pwd`
  cd ~/

  if [ ! -f ".pypirc" ]; then
    info "[add_pypi_config] no '.pypirc' going to create it"
    echo "[pypi]" > .pypirc
    echo "username = __token__" >> .pypirc
    echo "password = $PYPI_TOKEN" >> .pypirc
  fi
  cd "$_pwd"
  info "[add_pypi_config] ...done."
}

############################
#   name: assert_uv_config
#   purpose: ensures the 'uv' Python package manager is installed (installs via the official install script if absent);
#            then runs 'uv init' if no pyproject.toml exists, or 'uv sync' otherwise
#   parameters: none
#   requires: this_folder (project root)
############################

assert_uv_config(){
  info "[assert_uv_config|in]"

  which uv 1>/dev/null
  if [ "$?" -ne "0" ]; then 
    curl -LsSf https://astral.sh/uv/install.sh | sh
    [ "$?" -ne "0" ] && err "[assert_uv_config|out] failed" && exit 1
  fi

  _pwd=`pwd`
  cd "$this_folder"
  if [ ! -f "$this_folder/pyproject.toml" ]; then
    uv init
    result="$?"
    [ "$result" -ne "0" ] && err "[assert_uv_config|out] failed to 'uv init'"
  else
    uv sync
    result="$?"
    [ "$result" -ne "0" ] && err "[assert_uv_config|out] failed to 'uv sync'"
  fi
  cd "$_pwd"

  [ "$result" -ne "0" ] && err "[assert_uv_config|out]  => ${result}" && exit 1
  info "[assert_uv_config|out]"
}

############################
#   name: print_uuid
#   purpose: generates and prints a new UUID using uuidgen
#   parameters: none
#   requires: uuidgen
############################

print_uuid(){
  info "[print_uuid|in] ($1)"

  UUID=$(uuidgen)
  echo "generated UUID => $UUID"

  echo "[print_uuid|out]"
}



############################
#   name: collect_dot_git
#   purpose: archives the .git directory of the project into a compressed tar archive
#   parameters: $1 (output archive filename, default: git.tar.gz)
#   requires: tar, this_folder
############################
collect_dot_git(){
  info "[collect_dot_git|in] ($1)"
  _pwd=`pwd`
  cd "$this_folder"

  local OUTPUT_FILE="${1:-git.tar.gz}"
  tar czpvf "$OUTPUT_FILE" .git 
  local result="$?"

  cd "$_pwd"
  local msg="[collect_dot_git|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: create_release_documentation
#   purpose: assembles release documentation artifacts (git archive, PR approval PDF, QA PDF) into a single directory and compresses it into a tar archive
#   parameters: $1 (git archive tar file path), $2 (PR approvals PDF file path), $3 (QA report PDF file path), $4 (output target directory)
#   requires: tar, this_folder
############################
create_release_documentation(){
  info "[create_release_documentation|in] ($1, $2, $3, $4)"

  local GIT_TAR="$1"
  local PRS_PDF="$2"
  local QA_PDF="$3"
  local TARGET_DIR="$4"

  if [ -z "$GIT_TAR" ] || [ -z "$PRS_PDF" ] || [ -z "$QA_PDF" ] || [ -z "$TARGET_DIR" ]; then
    err "[create_release_documentation] missing required arguments: GIT_TAR, PRS_PDF, QA_PDF, TARGET_DIR" && exit 1
  fi

  _pwd=`pwd`
  cd "$this_folder"

  rm -f "$TARGET_DIR/*"
  mkdir -p "$TARGET_DIR"
  mv "$GIT_TAR" "$TARGET_DIR/"
  mv "$PRS_PDF" "$TARGET_DIR/"
  mv "$QA_PDF" "$TARGET_DIR/"

  tar czpvf "${TARGET_DIR}.tar.gz" "$TARGET_DIR" 
  local result="$?"
  cd "$_pwd"

  local msg="[create_release_documentation|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: function_report_wrapper
#   purpose: wraps a command invocation, appending its stdout output to a report file with labelled start/end section markers; propagates the command's exit code
#   parameters: $1 (report file path to append to), $2 (section label), $3+ (command and arguments to run)
#   returns: exit code of the wrapped command
############################
function_report_wrapper(){
  [ -z "$1" ] && { err "[function_report_wrapper] missing report path argument"; return 1; }
  local report_path="$1"
  shift
  [ -z "$1" ] && { err "[function_report_wrapper] missing report section name argument"; return 1; }
  local section_name="$1"
  shift
  [ "$#" -lt 1 ] && { err "[function_report_wrapper] missing command to run"; return 1; }

  {
    echo "## $section_name - section start"
    echo
    "$@"
    local cmd_rc=$?
    echo
    echo "## $section_name - section end"
    echo
    exit "$cmd_rc"
  } | tee -a "$report_path"

  local result=${PIPESTATUS[0]}
  return "$result"
}

############################
#   name: generate_pr_approvals_md
#   purpose: generates a markdown report of PR approvals for a given repository branch using tgedr_pycommons
#   parameters: $1 (repository name), $2 (branch name), $3 (output markdown file path)
#   requires: uv (with tgedr_pycommons)
############################
generate_pr_approvals_md() {
  local repo="$1"
  local branch="$2"
  local output_file="$3"

  if [ -z "$repo" ] || [ -z "$branch" ] || [ -z "$output_file" ]; then
    err "[generate_pr_approvals_md] missing required arguments: repo, branch, output_file" && exit 1
  fi

  uv run python -c "from tgedr_pycommons.cicd.pr_report_generator import generate_pr_approvals_md; generate_pr_approvals_md('$repo', '$branch', '$output_file')"
}

############################
#   name: generate_pdf_from_md
#   purpose: converts a markdown file to a PDF using tgedr_pycommons
#   parameters: $1 (input markdown file path), $2 (output PDF file path)
#   requires: uv (with tgedr_pycommons)
############################
generate_pdf_from_md() {

  [ -z "$1" ] && { err "[generate_pdf_from_md] missing input_md argument"; return 1; }
  local input_md="$1"
  [ -z "$2" ] && { err "[generate_pdf_from_md] missing output_pdf argument"; return 1; }
  local output_pdf="$2"

  uv run python -c "from tgedr_pycommons.cicd.markdown_to_pdf import convert; convert('$input_md', '$output_pdf')"
}

