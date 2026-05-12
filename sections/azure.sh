##########################################
#######   ------- azure -------    #######
##########################################

############################
#   name: az_sp_assign_subscription
#   purpose: grants Contributor role to a service principal on the specified Azure subscription
#   parameters: none
#   requires: APP_ID (service principal app/client ID), ARM_SUBSCRIPTION_ID, az
############################
az_sp_assign_subscription()
{
  info "[az_sp_assign_subscription|in]"
  az role assignment create --assignee "${APP_ID}" --role "Contributor" --scope "/subscriptions/${ARM_SUBSCRIPTION_ID}"
  info "[az_sp_assign_subscription|out]"
}

############################
#   name: az_sp_login
#   purpose: authenticates the Azure CLI using service principal credentials (non-interactive)
#   parameters: none
#   requires: APP_ID (client ID), ARM_CLIENT_SECRET, ARM_TENANT_ID, az
############################

az_sp_login()
{
  info "[az_sp_login|in]"
  az login --service-principal -u "${APP_ID}" -p "${ARM_CLIENT_SECRET}" --tenant "${ARM_TENANT_ID}" #--subscription "${ARM_SUBSCRIPTION_ID}"
  info "[az_sp_login|out]"
}

############################
#   name: az_login_check
#   purpose: validates that the current Azure CLI session is active by performing a lightweight read-only API call
#   parameters: none
#   requires: az
############################

az_login_check()
{
  info "[az_login_check|in]"
  az vm list-sizes --location westus
  info "[az_login_check|out]"
}

############################
#   name: az_logout
#   purpose: signs out of the Azure CLI, clearing all cached credentials
#   parameters: none
#   requires: az
############################

az_logout()
{
  info "[az_logout|in]"
  az logout
  info "[az_logout|out]"
}

############################
#   name: az_list_sp_roles
#   purpose: lists all role assignments (principalName, role, scope) for a given service principal
#   parameters: $1 (service principal app display name or object ID)
#   requires: az
############################

az_list_sp_roles()
{
  info "[az_list_sp_roles|in] ($1)"

  [ -z "$1" ] && err "no sp app display name provided" && exit 1
  sp_app_name="$1"
  az role assignment list --all --assignee "${sp_app_name}" --output json --query '[].{principalName:principalName, roleDefinitionName:roleDefinitionName, scope:scope}'

  info "[az_list_sp_roles|out]"
}

############################
#   name: az_storage_account_web_config
#   purpose: enables static website hosting on an Azure Blob storage account (index: index.html, 404: 404.html),
#            adds permissive CORS if not already configured, and stores the resulting website URL
#            in the variables file via add_entry_to_variables
#   parameters: $1 (storage account name), $2 (resource group name)
#   requires: az, add_entry_to_variables
############################

az_storage_account_web_config(){
  info "[az_storage_account_web_config|in] ($1, $2)"

  [ -z "$1" ] && err "[az_storage_account_web_config] no STORAGE_ACCOUNT param provided" && exit 1
  local STORAGE_ACCOUNT="$1"
  [ -z "$2" ] && err "[az_storage_account_web_config] no resource group provided" && exit 1
  local RESOURCE_GROUP="$2"

  az storage blob service-properties update --account-name "$STORAGE_ACCOUNT" --static-website true \
    --index-document "index.html" --404-document "404.html" #--debug --verbose 
  result="$?"

  if [ "$result" -eq "0" ]; then
    cors_config=$(az storage cors list --account-name pvdi0textmining0website)
    cors_result="$?"
    info "[az_storage_account_web_config] cors_config result: $?"
    info "[az_storage_account_web_config] cors_config: ->$cors_config<-"

    if [[ "$cors_result" -eq "0" && "$cors_config" != "[]" ]]; then
      warn "[az_storage_account_web_config] there is cors config already"
    else
      info "[az_storage_account_web_config] there is no cors config, goint to set it up"
      az storage cors add --account-name "$STORAGE_ACCOUNT" --services b --methods GET --origins "*" --allowed-headers "*" --exposed-headers "*"
      result="$?"
    fi
  fi

  if [ "$result" -eq "0" ]; then
    url=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "primaryEndpoints.web" --output tsv) && \
      add_entry_to_variables WEBSITE_URL "\"$url\""
    result="$?"
  fi

  [ "$result" -ne "0" ] && err "[az_storage_account_web_config|out] could not configure bucket" && exit 1

  info "[az_storage_account_web_config|out] => ${result}"
}

############################
#   name: az_upload_static_website
#   purpose: uploads all files from a local folder to the '$web' blob container of an Azure storage account (overwrites existing blobs)
#   parameters: $1 (storage account name), $2 (local source folder path)
#   requires: az
############################

az_upload_static_website(){
  info "[az_upload_static_website|in] ($1, $2)"

  [ -z "$1" ] && err "[az_upload_static_website] no STORAGE_ACCOUNT param provided" && exit 1
  local STORAGE_ACCOUNT="$1"
  [ -z "$2" ] && err "[az_upload_static_website] no SOURCE_FOLDER param provided" && exit 1
  local SOURCE_FOLDER="$2"

  az storage blob upload-batch --account-name $STORAGE_ACCOUNT --source $SOURCE_FOLDER --destination '$web' --debug --verbose --overwrite

  result="$?"
  [ "$result" -ne "0" ] && err "[az_upload_static_website|out] could not configure bucket" && exit 1

  info "[az_upload_static_website|out] => ${result}"
}

############################
#   name: get_azure_access_token
#   purpose: obtains an OAuth2 access token from Azure AD using client credentials flow
#            and persists it as AZURE_ACCESS_TOKEN in the secrets file via add_entry_to_secrets
#   parameters: $1 (Azure tenant ID), $2 (client/app ID), $3 (client secret), $4 (OAuth2 scope, e.g. 'https://management.azure.com/.default')
#   requires: curl, jq, add_entry_to_secrets
############################

get_azure_access_token(){
  info "[get_azure_access_token|in] ($1, $2, ${3:0:3}, $4)"

  [ -z $1 ] && err "[get_azure_access_token] missing argument TENANT_ID" && exit 1
  TENANT_ID="$1"
  [ -z $2 ] && err "[get_azure_access_token] missing argument BIFROST_CLIENT_ID" && exit 1
  BIFROST_CLIENT_ID="$2"
  [ -z $3 ] && err "[get_azure_access_token] missing argument APP_REG_CLIENT_SECRET" && exit 1
  BIFROST_CLIENT_SECRET="$3"
  [ -z $4 ] && err "[get_azure_access_token] missing argument SCOPE" && exit 1
  SCOPE="$4"


  local azure_token_api=https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token

  local response=$(curl -s -X POST "${azure_token_api}" -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=${BIFROST_CLIENT_ID}" \
      --data-urlencode "client_secret=${BIFROST_CLIENT_SECRET}" \
      --data-urlencode "scope=${SCOPE}" )
  result="$?"
  access_token=$(echo "$response" | jq -r '.access_token')
  add_entry_to_secrets "AZURE_ACCESS_TOKEN" "$access_token"

  [ "$result" -ne "0" ] && err "[get_azure_access_token|out]  => ${result}" && exit 1
  info "[get_azure_access_token|out] => ${access_token}"
}
