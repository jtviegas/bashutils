##########################################
####### ------- databricks ------- #######
##########################################

############################
#   name: databricks_set_cli_access
#   purpose: authenticates interactively with Azure, retrieves a Databricks access token,
#            and persists DATABRICKS_HOST and DATABRICKS_TOKEN via add_entry_to_variables/add_entry_to_secrets
#   parameters: $1 (Databricks workspace URL, e.g. https://<workspace>.azuredatabricks.net), $2 (Azure subscription ID)
#   requires: az, add_entry_to_variables, add_entry_to_secrets
############################
databricks_set_cli_access()
{
  info "[databricks_set_cli_access|in] ($1, $2)"
  [ -z "$2" ] && err "no subscription Id provided" && return 1
  [ -z "$1" ] && err "no workspace url provided" && return 1

  # dd62d6ec-d618-49ad-bd43-04a2ef12c0fb

  az login
  az account set --subscription "$2"
  token=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query "accessToken" --output tsv)
  add_entry_to_variables DATABRICKS_HOST "$1"
  add_entry_to_secrets DATABRICKS_TOKEN "$token"
  info "[databricks_set_cli_access|out]"
}

############################
#   name: databricks_bundle_deploy
#   purpose: validates and deploys a Databricks Asset Bundle to the specified target environment
#   parameters: $1 (path to the bundle folder containing databricks.yml), $2 (deployment target: local | main, default: local)
#   requires: databricks
############################

databricks_bundle_deploy(){
  info "[databricks_bundle_deploy|in]"

  [ -z $1 ] && err "[databricks_bundle_deploy] missing argument BUNDLE_FOLDER" && exit 1
  local BUNDLE_FOLDER="$1"
  local BUNDLE_TARGET="local"
  [ ! -z $2 ] && BUNDLE_TARGET="$2"

  [ "main" != "$BUNDLE_TARGET" ] && [ "local" != "$BUNDLE_TARGET" ] && err "[databricks_bundle_deploy] wrong argument BUNDLE_TARGET: $BUNDLE_TARGET" && exit 1
  info "[databricks_bundle_deploy] BUNDLE_FOLDER: $BUNDLE_FOLDER   BUNDLE_TARGET: $BUNDLE_TARGET"

  _pwd=`pwd`
  cd "$BUNDLE_FOLDER"

  databricks bundle validate --target "$BUNDLE_TARGET" --debug && \
    databricks bundle deploy --target "$BUNDLE_TARGET" --auto-approve --fail-on-active-runs --force-lock --debug

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[databricks_bundle_deploy|out]  => ${result}" && exit 1
  info "[databricks_bundle_deploy|out] => ${result}"
}

############################
#   name: databricks_bundle_destroy
#   purpose: destroys all resources managed by a Databricks Asset Bundle in the specified target environment
#   parameters: $1 (path to the bundle folder containing databricks.yml), $2 (deployment target: local | main, default: local)
#   requires: databricks
############################

databricks_bundle_destroy(){
  info "[databricks_bundle_destroy|in]"

  [ -z $1 ] && err "[databricks_bundle_destroy] missing argument BUNDLE_FOLDER" && exit 1
  local BUNDLE_FOLDER="$1"
  local BUNDLE_TARGET="local"
  [ ! -z $2 ] && BUNDLE_TARGET="$2"

  [ "main" != "$BUNDLE_TARGET" ] && [ "local" != "$BUNDLE_TARGET" ] && err "[databricks_bundle_destroy] wrong argument BUNDLE_TARGET: $BUNDLE_TARGET" && exit 1
  info "[databricks_bundle_destroy] BUNDLE_FOLDER: $BUNDLE_FOLDER   BUNDLE_TARGET: $BUNDLE_TARGET"

  _pwd=`pwd`
  cd "$BUNDLE_FOLDER"

  databricks bundle destroy --target "$BUNDLE_TARGET" --auto-approve --force-lock --debug

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[databricks_bundle_destroy|out]  => ${result}" && exit 1
  info "[databricks_bundle_destroy|out] => ${result}"
}

############################
#   name: databricks_delete_secret
#   purpose: removes a secret key from a Databricks secret scope
#   parameters: $1 (secret key name), $2 (secret scope name)
#   requires: databricks
############################

databricks_delete_secret(){
  info "[databricks_delete_secret|in] ($1, $2)"

  [ -z $1 ] && err "[databricks_delete_secret] missing argument SECRET_KEY" && exit 1
  local SECRET_KEY="$1"
  [ -z $2 ] && err "[databricks_delete_secret] missing argument SECRET_SCOPE" && exit 1
  local SECRET_SCOPE="$2"

  databricks secrets delete-secret $SECRET_SCOPE $SECRET_KEY
  result="$?"

  [ "$result" -ne "0" ] && err "[databricks_delete_secret|out] could not delete the secret" && exit 1
  info "[databricks_delete_secret|out] => ${result}"
}

############################
#   name: databricks_set_secret
#   purpose: creates a secret in a Databricks secret scope if it does not already exist; warns if already present
#   parameters: $1 (secret key name), $2 (secret scope name), $3 (secret string value)
#   requires: databricks
############################

databricks_set_secret(){
  info "[databricks_set_secret|in] ($1, $2, ${3:0:3})"

  [ -z $1 ] && err "[databricks_set_secret] missing argument SECRET_KEY" && exit 1
  local SECRET_KEY="$1"
  [ -z $2 ] && err "[databricks_set_secret] missing argument SECRET_SCOPE" && exit 1
  local SECRET_SCOPE="$2"
  [ -z $3 ] && err "[databricks_set_secret] missing argument SECRET_VALUE" && exit 1
  local SECRET_VALUE="$3"

  query=$(databricks secrets get-secret $SECRET_SCOPE $SECRET_KEY)
  if [ "$?" -ne "0" ]; then
    info "[databricks_set_secret] creating secret $SECRET_KEY in scope $SECRET_SCOPE"
    databricks secrets put-secret "$SECRET_SCOPE" "$SECRET_KEY" --string-value "$SECRET_VALUE"
  else
    warn "[databricks_set_secret] secret is already there"
  fi
  result="$?"
  [ "$result" -ne "0" ] && err "[databricks_set_secret|out]  => ${result}" && exit 1
  info "[databricks_set_secret|out] => ${result}"
}


############################
#   name: get_azure_artifact
#   purpose: downloads a universal package from an Azure DevOps artifacts feed using the Azure CLI
#   parameters: $1 (Azure DevOps organization URL), $2 (feed name), $3 (package name),
#               $4 (package version), $5 (local download path, default: current directory)
#   requires: az (with azure-devops extension)
############################

get_azure_artifact(){
  info "[get_azure_artifact|in] ($1, $2, $3, $4, $5)"

  [ -z "$1" ] && err "[get_azure_artifact] missing argument ORGANIZATION" && exit 1
  local ORGANIZATION="$1"
  [ -z "$2" ] && err "[get_azure_artifact] missing argument FEED" && exit 1
  local FEED="$2"
  [ -z "$3" ] && err "[get_azure_artifact] missing argument NAME" && exit 1
  local NAME="$3"
  [ -z "$4" ] && err "[get_azure_artifact] missing argument VERSION" && exit 1
  local VERSION="$4"

  local TARGET="."
  [ ! -z "$5" ] && TARGET="$5"
  [ ! -d "$TARGET" ] && mkdir -p "$TARGET"

  az artifacts universal download --organization "$ORGANIZATION" --feed "$FEED" --name "$NAME" --version "$VERSION" --path "$TARGET"
  result="$?"

  [ "$result" -ne "0" ] && err "[get_azure_artifact|out] => ${result}" && exit 1
  info "[get_azure_artifact|out] => ${result}"
}
