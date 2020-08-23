# http://bash.cumulonim.biz/NullGlob.html
shopt -s nullglob

# ---------- CONSTANTS ----------
export DEFAULT_TF_MODULES_DIR_NAME=modules
# -------------------------------

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

get_terraform_modules() {
  info "[get_terraform_modules|in] ...( $@ )"
  local usage_msg=$'get_terraform_modules: downloads terraform modules from a github repo:\nusage:\n    get_terraform_modules MODULES_URL DESTINATION_DIR'

  if [ -z "$2" ] ; then echo "$usage_msg" && return 1; fi
  local url="$1"
  local folder="$2"

  verify_env DEFAULT_TF_MODULES_DIR_NAME
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  verify_prereqs svn
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  local _pwd=$(pwd)
  cd "$folder"
  svn export -q "$url" "$DEFAULT_TF_MODULES_DIR_NAME"
  if [ ! "$?" -eq "0" ]; then err "[get_terraform_modules] could not download terraform modules" && cd "$_pwd" && return 1; fi

  cd "$_pwd"
  info "[get_terraform_modules|out] ...done."
}

delete_terraform_modules() {
  info "[delete_terraform_modules|in] ...( $@ )"
  local usage_msg=$'delete_terraform_modules: deletes the previously downloaded terraform modules folder:\nusage:\n    delete_terraform_modules TF_BASE_DIR'

  if [ -z "$1" ] ; then echo "$usage_msg" && return 1; fi
  local folder="$1"

  verify_env DEFAULT_TF_MODULES_DIR_NAME
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  if [ -d "$folder/$DEFAULT_TF_MODULES_DIR_NAME" ]; then
    rm -r "$folder/$DEFAULT_TF_MODULES_DIR_NAME"
    if [ ! "$?" -eq "0" ]; then err "[delete_terraform_modules] could not delete terraform modules folder" && return 1; fi
  fi

  info "[delete_terraform_modules|out] ...done."
}


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

download_function(){
  info "[download_function|in] ...( $@ )"
  local usage_msg=$'download_function: downloads a function release artifact from github:\nusage:\n    download_function REPO ARTIFACT DESTINATION_FILE'

  if [ -z "$3" ] ; then echo "$usage_msg" && return 1; fi
  local repo="$1"
  local artifact="$2"
  local file="$3"

  curl -s "https://api.github.com/repos/${repo}/releases/latest" \
  | grep "browser_download_url.*${artifact}" \
  | cut -d '"' -f 4 | wget -O "$file" -qi  -
  if [ ! "$?" -eq "0" ]; then err "[download_function] curl command was not successful" && return 1; fi

  info "[download_function|out] ...done."
}

tf_resources_on() {
  info "[tf_resources_on|in] ...( $@ )"
  local usage_msg=$'tf_resources_on: sets up terraform resources for a project:\nusage:\n    required environment variables:\n    AWS_REGION AWS_ACCOUNT_ID TERRAFORM_DIR TERRAFORM_RESOURCES_CONFIG TERRAFORM_RESOURCES_CONFIG_TEMPLATE TERRAFORM_RESOURCES_DIR APPLICATION ENVIRONMENT MODULES_URL FUNCTION_NAME FUNCTION_FILE FUNCTION_REPO\n    tf_resources_on'

  verify_env AWS_REGION AWS_ACCOUNT_ID TERRAFORM_DIR TERRAFORM_RESOURCES_CONFIG TERRAFORM_RESOURCES_CONFIG_TEMPLATE TERRAFORM_RESOURCES_DIR APPLICATION ENVIRONMENT MODULES_URL FUNCTION_NAME FUNCTION_FILE FUNCTION_REPO
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  local custom_tf_config="$this_folder/$TERRAFORM_RESOURCES_CONFIG"
  local config_template="$this_folder/$TERRAFORM_RESOURCES_CONFIG_TEMPLATE"
  local tf_dir="$this_folder/$TERRAFORM_DIR"
  local tf_resources_dir="$this_folder/$TERRAFORM_RESOURCES_DIR"

  if [ -f "$custom_tf_config" ]; then rm "$custom_tf_config";fi
  create_from_template_and_envvars "$config_template" "$custom_tf_config" AWS_REGION APPLICATION ENVIRONMENT

  delete_terraform_modules "$tf_dir"
  get_terraform_modules "$MODULES_URL" "$tf_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_resources_on] could not get terraform modules" && return 1; fi

  if [ -f "$tf_resources_dir/$FUNCTION_FILE" ]; then rm "$tf_resources_dir/$FUNCTION_FILE";fi
  download_function "$FUNCTION_REPO" "$FUNCTION_FILE" "$tf_resources_dir/$FUNCTION_FILE"
  if [ ! "$?" -eq "0" ]; then err "[tf_resources_on] could not download the function" && return 1; fi

  export TF_VAR_aws_region="$AWS_REGION"
  export TF_VAR_application="$APPLICATION"
  export TF_VAR_environment="$ENVIRONMENT"
  export TF_VAR_function="$FUNCTION_NAME"
  export TF_VAR_function_file="$FUNCTION_FILE"
  export TF_VAR_aws_account_id="$AWS_ACCOUNT_ID"

  terraform_autodeploy "$tf_resources_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_resources_on] could not setup terraform resources" && return 1; fi

  info "[tf_resources_on|out] ...done."
}

tf_resources_off() {
  info "[tf_resources_off|in] ...( $@ )"
  local usage_msg=$'tf_resources_off: destroys terraform resources for a project:\nusage:\n    required environment variables:\n    AWS_REGION AWS_ACCOUNT_ID TERRAFORM_DIR TERRAFORM_RESOURCES_CONFIG TERRAFORM_RESOURCES_CONFIG_TEMPLATE TERRAFORM_RESOURCES_DIR APPLICATION ENVIRONMENT MODULES_URL FUNCTION_NAME FUNCTION_FILE\n    tf_resources_off'

  verify_env AWS_REGION AWS_ACCOUNT_ID TERRAFORM_DIR TERRAFORM_RESOURCES_CONFIG TERRAFORM_RESOURCES_CONFIG_TEMPLATE TERRAFORM_RESOURCES_DIR APPLICATION ENVIRONMENT MODULES_URL FUNCTION_NAME FUNCTION_FILE
  if [ ! "$?" -eq "0" ] ; then return 1; fi

  local custom_tf_config="$this_folder/$TERRAFORM_RESOURCES_CONFIG"
  local config_template="$this_folder/$TERRAFORM_RESOURCES_CONFIG_TEMPLATE"
  local tf_dir="$this_folder/$TERRAFORM_DIR"
  local tf_resources_dir="$this_folder/$TERRAFORM_RESOURCES_DIR"

  if [ -f "$custom_tf_config" ]; then rm "$custom_tf_config";fi
  create_from_template_and_envvars "$config_template" "$custom_tf_config" AWS_REGION APPLICATION ENVIRONMENT

  delete_terraform_modules "$tf_dir"
  get_terraform_modules "$MODULES_URL" "$tf_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_resources_on] could not get terraform modules" && return 1; fi

  export TF_VAR_aws_region="$AWS_REGION"
  export TF_VAR_application="$APPLICATION"
  export TF_VAR_environment="$ENVIRONMENT"
  export TF_VAR_function="$FUNCTION_NAME"
  export TF_VAR_function_file="$FUNCTION_FILE"
  export TF_VAR_aws_account_id="$AWS_ACCOUNT_ID"

  terraform_autodestroy "$tf_resources_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_resources_off] could not destroy terraform resources" && return 1; fi

  info "[tf_resources_off|out] ...done."
}

tf_state_on() {
  info "[tf_state_on|in] ...( $@ )"
  local usage_msg=$'tf_state_on: sets up terraform remote state for a project:\nusage:\n    required environment variables:\n    AWS_REGION TERRAFORM_DIR TERRAFORM_STATE_DIR MODULES_URL APPLICATION ENVIRONMENT DEFAULT_TF_MODULES_DIR_NAME\n    tf_state_on'

  verify_env AWS_REGION TERRAFORM_DIR TERRAFORM_STATE_DIR MODULES_URL APPLICATION ENVIRONMENT DEFAULT_TF_MODULES_DIR_NAME
  if [ ! "$?" -eq "0" ] ; then echo "$usage_msg" && return 1; fi

  local tf_dir="$this_folder/$TERRAFORM_DIR"
  local state_dir="$this_folder/$TERRAFORM_STATE_DIR"

  delete_terraform_modules "$tf_dir"
  get_terraform_modules "$MODULES_URL" "$tf_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_state_on] could not get terraform modules" && return 1; fi

  export TF_VAR_region="$AWS_REGION"
  export TF_VAR_app="$APPLICATION"
  export TF_VAR_env="$ENVIRONMENT"

  terraform_autodeploy "$state_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_state_on] could not setup terraform remote state" && return 1; fi

  info "[tf_state_on|out] ...done."
}

tf_state_off() {
  info "[tf_state_off|in] ...( $@ )"
  local usage_msg=$'tf_state_off: deletes terraform remote state for a project:\nusage:\n    required environment variables:\n    AWS_REGION TERRAFORM_DIR TERRAFORM_STATE_DIR MODULES_URL APPLICATION ENVIRONMENT DEFAULT_TF_MODULES_DIR_NAME\n    tf_state_off'

  verify_env AWS_REGION TERRAFORM_DIR TERRAFORM_STATE_DIR MODULES_URL APPLICATION ENVIRONMENT DEFAULT_TF_MODULES_DIR_NAME
  if [ ! "$?" -eq "0" ] ; then echo "$usage_msg" && return 1; fi

  local tf_dir="$this_folder/$TERRAFORM_DIR"
  local state_dir="$this_folder/$TERRAFORM_STATE_DIR"

  delete_terraform_modules "$tf_dir"
  get_terraform_modules "$MODULES_URL" "$tf_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_state_off] could not get terraform modules" && return 1; fi

  export TF_VAR_region="$AWS_REGION"
  export TF_VAR_app="$APPLICATION"
  export TF_VAR_env="$ENVIRONMENT"

  terraform_autodestroy "$state_dir"
  if [ ! "$?" -eq "0" ]; then err "[tf_state_off] could not delete terraform remote state" && return 1; fi

  info "[tf_state_off|out] ...done."
}

