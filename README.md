# bashutils
bash scripting utilities include file 

## usage

include the file in your bash script:

`. ${this_folder}/.bashutils`

## suggestions for the bash script

- header section

  ```
  #!/usr/bin/env bash

  # ===> HEADER SECTION START  ===>

  # http://bash.cumulonim.biz/NullGlob.html
  shopt -s nullglob
  # -------------------------------
  this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  if [ -z "$this_folder" ]; then
    this_folder=$(dirname $(readlink -f $0))
  fi
  parent_folder=$(dirname "$this_folder")

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

  file_age_days() {
    local file="$1"
    local file_time
    local current_time

    if [[ "$OSTYPE" == "darwin"* ]]; then
        file_time=$(stat -f %m "$file")
    else
        file_time=$(stat -c %Y "$file")
    fi

    current_time=$(date +%s)
    echo $(( (current_time - file_time) / 86400 ))
  }

  # ---------- CONSTANTS ----------
  export FILE_VARIABLES=${FILE_VARIABLES:-".variables"}
  export FILE_LOCAL_VARIABLES=${FILE_LOCAL_VARIABLES:-".local_variables"}
  export FILE_SECRETS=${FILE_SECRETS:-".secrets"}
  export INCLUDE_FILE=".bashutils"

  # -------------------------------
  # --- source variables files
  if [ ! -f "$this_folder/$FILE_VARIABLES" ]; then
    warn "we DON'T have a $FILE_VARIABLES variables file - creating it"
    touch "$this_folder/$FILE_VARIABLES"
  else
    . "$this_folder/$FILE_VARIABLES"
  fi

  if [ ! -f "$this_folder/$FILE_LOCAL_VARIABLES" ]; then
    warn "we DON'T have a $FILE_LOCAL_VARIABLES variables file - creating it"
    touch "$this_folder/$FILE_LOCAL_VARIABLES"
  else
    . "$this_folder/$FILE_LOCAL_VARIABLES"
  fi

  if [ ! -f "$this_folder/$FILE_SECRETS" ]; then
    warn "we DON'T have a $FILE_SECRETS secrets file - creating it"
    touch "$this_folder/$FILE_SECRETS"
  else
    . "$this_folder/$FILE_SECRETS"
  fi

  # ---------- include bashutils ----------
  # --- refresh file if older than 1 day
  bashutils="$this_folder/$INCLUDE_FILE"
  [ $(file_age_days "$bashutils") -gt 1 ] && \
    curl -sf https://raw.githubusercontent.com/jtviegas/bashutils/master/.bashutils -o "${bashutils}.tmp" && \
    mv "${bashutils}.tmp" "$bashutils"
  # --- source it
  . $bashutils

  # <=== HEADER SECTION END  <===
  ```
- main section

  ```
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

  # <=== MAIN SECTION END  <===
  ```

- footer section

  ```
  # ===> FOOTER SECTION START  ===>

  usage() {
    cat <<EOM
    usage:
    $(basename $0) { option }
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
  ```


## notes

- the header snippet tries to:
  - include variables and secrets into the running environment through the files `.variables`, `.local_variables` (for local user specific variables) and `.secrets` in this order 
(these last two _should not be included in versioning_, add them to `.gitignore` file)
  - it also defines handy logging functions
  - ...and a function to realize how old is a file...
  - ...that is used to check if the `.bashutils` include file is older than 1 day, and in that case downloads its latest version before including it

