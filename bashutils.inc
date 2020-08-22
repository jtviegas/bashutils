# http://bash.cumulonim.biz/NullGlob.html
shopt -s nullglob


if [ -z "$this_folder" ]; then
  this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  if [ -z "$this_folder" ]; then
    this_folder=$(dirname $(readlink -f $0))
  fi
fi
if [ -z "$parent_folder" ]; then
  parent_folder=$(dirname "$this_folder")
fi


debug(){
    local __msg="$@"
    echo " [DEBUG] `date` ... $__msg "
}

info(){
    local __msg="$@"
    echo " [INFO]  `date` ->>> $__msg "
}

warn(){
    local __msg="$@"
    echo " [WARN]  `date` *** $__msg "
}

err(){
    local __msg="$@"
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

if [ ! -z "$ADDITIONAL_VARIABLES" ]; then
  debug "loading ADDITIONAL_VARIABLES"
  . "$ADDITIONAL_VARIABLES"
fi

if [ ! -z "$ADDITIONAL_SECRETS" ]; then
  debug "loading ADDITIONAL_SECRETS"
  . "$ADDITIONAL_SECRETS"
fi

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

verify_env(){
  info "[verify_env] ..."
  for arg in "$@"
  do
      debug "[verify_env] ... checking $arg"
      if [ -z "$arg" ]; then err "[verify_env] please define env var: $arg" && return 1; fi
  done
  info "[verify_env] ...done."
}

npm_publish(){
  info "[npm_publish] ..."

  verify_prereqs npm
  if [ ! "$?" -eq "0" ] ; then return 1; fi
  verify_env NPM_REGISTRY NPM_TOKEN
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  _pwd=`pwd`
  cd "$this_folder"
  npm config set "//${NPM_REGISTRY}/:_authToken" "${NPM_TOKEN}"
  npm publish . --access="public"
  if [ ! "$?" -eq "0" ]; then err "[npm_publish] could not publish" && cd "$_pwd" && return 1; fi
  cd "$_pwd"
  info "[npm_publish] ...done."
}

terraform_autodeploy(){
  info "[terraform_autodeploy] ..."

  [ -z $1 ] && err "[terraform_autodeploy] missing function argument FOLDER" && return 1
  local folder="$1"

  verify_prereqs terraform
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  _pwd=$(pwd)
  cd "$folder"

  terraform init
  terraform plan
  terraform apply -auto-approve -lock=true -lock-timeout=10m
  if [ ! "$?" -eq "0" ]; then err "[terraform_autodeploy] could not apply" && cd "$_pwd" && return 1; fi
  cd "$_pwd"
  info "[terraform_autodeploy] ...done."
}

terraform_autodestroy(){
  info "[terraform_autodestroy] ..."

  [ -z $1 ] && err "[terraform_autodestroy] missing function argument FOLDER" && return 1
  local folder="$1"

  verify_prereqs terraform
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  _pwd=$(pwd)
  cd "$folder"

  terraform destroy -auto-approve -lock=true -lock-timeout=10m
  if [ ! "$?" -eq "0" ]; then err "[terraform_autodestroy] could not apply" && cd "$_pwd" && return 1; fi
  cd "$_pwd"
  info "[terraform_autodestroy] ...done."
}

zip_js_lambda_function(){
  info "[zip_js_lambda_function] ...( $@ )"
  local usage_msg=$'zip_js_lambda_function: zips a js lambda function:\nusage:\n    zip_js_lambda_function SRC_DIR ZIP_FILE { FILES FOLDERS ... }'

  verify_prereqs npm
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  if [ -z "$3" ] ; then echo "$usage_msg" && return 1; fi

  local src_dir="$1"
  local zip_file="$2"
  local files="${@:3}"
  local AWS_SDK_MODULE_PATH=$src_dir/node_modules/aws-sdk

  _pwd=`pwd`
  cd "$src_dir"

  if [ -f "package.json" ]; then
    npm install &>/dev/null
    if [ ! "$?" -eq "0" ] ; then err "[zip_js_lambda_function] could not install dependencies" && cd "$_pwd" && return 1; fi
    if [ -d "${AWS_SDK_MODULE_PATH}" ]; then rm -r "$AWS_SDK_MODULE_PATH"; fi
  fi

  rm -f "$zip_file"
  zip -9 -q -r "$zip_file" "$files" &>/dev/null
  if [ ! "$?" -eq "0" ] ; then err "[zip_js_lambda_function] could not zip it" && cd "$_pwd" && return 1; fi

  cd "$_pwd"
  info "[zip_js_lambda_function] ...done."
}

get_function_release(){
  info "[get_function_release] ...( $@ )"
  local usage_msg=$'get_function_release: retrieves a function release artifact from github:\nusage:\n    get_function_release REPO ARTIFACT'

  if [ -z "$2" ] ; then echo "$usage_msg" && return 1; fi
  local repo="$1"
  local artifact="$2"

  _pwd=`pwd`
  cd "$this_folder"

  curl -s "https://api.github.com/repos/${repo}/releases/latest" \
  | grep "browser_download_url.*${artifact}" \
  | cut -d '"' -f 4 | wget -qi -

  cd "$_pwd"
  info "[get_function_release] ...done."
}