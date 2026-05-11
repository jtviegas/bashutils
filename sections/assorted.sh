##########################################
#######  ------- assorted -------  #######
##########################################

############################
#   name: test_js_lambda
#   purpose: installs npm dependencies and runs Jest tests for a JavaScript Lambda function
#   parameters: $1 (path to the Lambda function directory containing package.json)
#   requires: npm, jest
############################
test_js_lambda(){
  info "[test_js_lambda|in] ({$1})"

  [ -z $1 ] && err "[get_cloudfront_cidr] missing argument FUNCTION_DIR" && exit 1
  local FUNCTION_DIR="$1"
  _pwd=`pwd`
  cd "$FUNCTION_DIR"

  npm install
  jest

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[test_js_lambda|out]  => ${result}" && exit 1
  info "[test_js_lambda|out] => ${result}"
}

############################
#   name: zip_js_lambda_function
#   purpose: packages a JavaScript Lambda function into a zip archive;
#            installs npm dependencies if package.json is present and removes the bundled aws-sdk
#            (provided by the Lambda runtime) to reduce bundle size
#   parameters: $1 (source directory), $2 (output zip file path), $3+ (files/folders to include in the zip)
#   requires: npm, zip
############################

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

############################
#   name: get_function_release
#   purpose: downloads a named artifact from the latest GitHub release of a repository into this_folder
#   parameters: $1 (GitHub repository in 'owner/repo' format), $2 (artifact filename to match)
#   requires: curl, wget, this_folder
############################

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

############################
#   name: download_function
#   purpose: downloads a named artifact from the latest GitHub release of a repository and saves it to a specific local file
#   parameters: $1 (GitHub repository in 'owner/repo' format), $2 (artifact filename to match), $3 (local destination file path)
#   requires: curl, wget
############################

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

############################
#   name: call_grafana_api
#   purpose: makes an authenticated GET request to a Grafana API endpoint through a proxy/gateway,
#            passing both an Azure bearer token and a Grafana service account token
#   parameters: $1 (Azure OAuth2 access token), $2 (Grafana service account API token)
#   requires: curl
############################

call_grafana_api(){
  info "[call_grafana_api|in] (${1:0:3}, ${2:0:3})"

  [ -z $1 ] && err "[call_grafana_api] missing argument AZURE_ACCESS_TOKEN" && exit 1
  AZURE_ACCESS_TOKEN="$1"
  [ -z $2 ] && err "[call_grafana_api] missing argument GRAFANA_API_TOKEN" && exit 1
  GRAFANA_API_TOKEN="$2"

  local response=$(curl -s -X GET "https://api.bifrost.heimdall.novonordisk.cloud/grafana/api/org"  \
      -H "Authorization: Bearer ${AZURE_ACCESS_TOKEN}" \
      -H "X-Bifrost-Grafana-SA: Bearer ${GRAFANA_API_TOKEN}" )
  result="$?"

  [ "$result" -ne "0" ] && err "[call_grafana_api|out]  => ${result}" && exit 1
  info "[call_grafana_api|out] => ${response}"
}
