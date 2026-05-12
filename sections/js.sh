##########################################
#######     ------- js -------     #######
##########################################

############################
#   name: npm_deps
#   purpose: runs 'npm install' in the specified project directory
#   parameters: $1 (path to the directory containing package.json)
#   requires: npm
############################
npm_deps(){
  info "[npm_deps|in] ($1)"

  [ -z $1 ] && err "[npm_deps] missing argument INFRA_DIR" && exit 1
  local INFRA_DIR="$1"

  _pwd=`pwd`
  cd "$INFRA_DIR"

  npm install

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[npm_deps|out]  => ${result}" && exit 1
  info "[npm_deps|out] => ${result}"
}

############################
#   name: npm_publish
#   purpose: authenticates against a private npm registry and publishes the package as public
#   parameters: $1 (registry hostname, e.g. npm.pkg.github.com), $2 (auth token), $3 (path to package folder)
#   requires: npm
############################

npm_publish(){
  info "[npm_publish|in] ($1, $2)"

  [ -z $1 ] && err "[npm_publish] missing argument NPM_REGISTRY" && return 1
  local registry="$1"
  [ -z $2 ] && err "[npm_publish] missing argument NPM_TOKEN" && return 1
  local token="$2"
  [ -z $3 ] && err "[npm_publish] missing argument FOLDER" && return 1
  local folder="$3"

  _pwd=`pwd`
  cd "$folder"
  npm config set "//${registry}/:_authToken" "${token}"
  npm publish . --access="public"
  if [ ! "$?" -eq "0" ]; then err "[npm_publish] could not publish" && cd "$_pwd" && return 1; fi
  cd "$_pwd"
  info "[npm_publish] ...done."
}
