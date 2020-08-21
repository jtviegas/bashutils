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