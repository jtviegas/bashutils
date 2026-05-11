##########################################
#######     ------- cdk -------    #######
##########################################

############################
#   name: cdk_global_reqs
#   purpose: globally installs all npm packages required for AWS CDK TypeScript development
#   parameters: $1 (typescript version), $2 (aws-cdk version), $3 (ts-node version),
#               $4 (@aws-cdk/integ-runner version), $5 (@aws-cdk/integ-tests-alpha version), $6 (jest version)
#   requires: npm
############################
cdk_global_reqs(){
  info "[cdk_global_reqs|in] ($1, $2, $3, $4, $5, $6)"

  [ -z $1 ] && err "[cdk_global_reqs] missing argument TYPESCRIPT_VERSION" && return 1
  local TYPESCRIPT_VERSION="$1"
  [ -z $2 ] && err "[cdk_global_reqs] missing argument CDK_VERSION" && return 1
  local CDK_VERSION="$2"
  [ -z $3 ] && err "[cdk_global_reqs] missing argument TS_NODE_VERSION" && return 1
  local TS_NODE_VERSION="$3"
  [ -z $4 ] && err "[cdk_global_reqs] missing argument INTEG_RUNNER_VERSION" && return 1
  local INTEG_RUNNER_VERSION="$4"
  [ -z $5 ] && err "[cdk_global_reqs] missing argument INTEG_TESTS_ALPHA_VERSION" && return 1
  local INTEG_TESTS_ALPHA_VERSION="$5"
  [ -z $6 ] && err "[cdk_global_reqs] missing argument JEST_VERSION" && return 1
  local JEST_VERSION="$6"

  npm install -g "typescript@${TYPESCRIPT_VERSION}" "aws-cdk@${CDK_VERSION}" "ts-node@${TS_NODE_VERSION}" \
   "@aws-cdk/integ-runner@${INTEG_RUNNER_VERSION}" "@aws-cdk/integ-tests-alpha@${INTEG_TESTS_ALPHA_VERSION}" \
   "jest@${JEST_VERSION}"
  result="$?"
  [ "$result" -ne "0" ] && err "[cdk_global_reqs|out]  => ${result}" && exit 1
  info "[cdk_global_reqs|out] => ${result}"
}

############################
#   name: cdk_scaffolding
#   purpose: initialises a new AWS CDK TypeScript app in the given directory using 'cdk init app'
#   parameters: $1 (path to the target infrastructure directory)
#   requires: cdk
############################

cdk_scaffolding(){
  info "[cdk_scaffolding|in] ($1)"

  [ -z $1 ] && err "[cdk_scaffolding] missing argument INFRA_DIR" && exit 1
  local INFRA_DIR="$1"

  _pwd=`pwd`
  cd "$INFRA_DIR"

  cdk init app --language typescript

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[cdk_scaffolding|out]  => ${result}" && exit 1
  info "[cdk_scaffolding|out] => ${result}"
}

############################
#   name: cdk_infra_bootstrap
#   purpose: convenience wrapper — installs global CDK npm dependencies then scaffolds a new CDK TypeScript app
#   parameters: $1 (typescript version), $2 (aws-cdk version), $3 (ts-node version),
#               $4 (@aws-cdk/integ-runner version), $5 (@aws-cdk/integ-tests-alpha version),
#               $6 (jest version), $7 (path to infrastructure directory)
#   requires: npm, cdk
############################

cdk_infra_bootstrap(){
  info "[cdk_infra_bootstrap|in] ($1, $2, $3, $4, $5, $6)"

  [ -z $1 ] && err "[cdk_infra_bootstrap] missing argument TYPESCRIPT_VERSION" && return 1
  local TYPESCRIPT_VERSION="$1"
  [ -z $2 ] && err "[cdk_infra_bootstrap] missing argument CDK_VERSION" && return 1
  local CDK_VERSION="$2"
  [ -z $3 ] && err "[cdk_infra_bootstrap] missing argument TS_NODE_VERSION" && return 1
  local TS_NODE_VERSION="$3"
  [ -z $4 ] && err "[cdk_infra_bootstrap] missing argument INTEG_RUNNER_VERSION" && return 1
  local INTEG_RUNNER_VERSION="$4"
  [ -z $5 ] && err "[cdk_infra_bootstrap] missing argument INTEG_TESTS_ALPHA_VERSION" && return 1
  local INTEG_TESTS_ALPHA_VERSION="$5"
  [ -z $6 ] && err "[cdk_infra_bootstrap] missing argument JEST_VERSION" && return 1
  local JEST_VERSION="$6"
  [ -z $7 ] && err "[cdk_infra_bootstrap] missing argument INFRA_DIR" && return 1
  local INFRA_DIR="$7"

  cdk_global_reqs "$TYPESCRIPT_VERSION" "$CDK_VERSION" "$TS_NODE_VERSION" "$INTEG_RUNNER_VERSION" \
    "$INTEG_TESTS_ALPHA_VERSION" "$JEST_VERSION"  && cdk_scaffolding "$INFRA_DIR"

  result="$?"
  [ "$result" -ne "0" ] && err "[cdk_infra_bootstrap|out]  => ${result}" && exit 1
  info "[cdk_infra_bootstrap|out] => ${result}"
}

############################
#   name: cdk_infra
#   purpose: manages a CDK stack lifecycle:
#            'on'        — synth then deploy (--require-approval=never)
#            'off'       — destroy (--force)
#            'bootstrap' — bootstrap the CDK toolkit in the account/region
#   parameters: $1 (operation: on | off | bootstrap),
#               $2 (infrastructure folder, default: infrastructure),
#               $3 (stacks selector, default: --all)
#   requires: cdk
############################

cdk_infra()
{
  # usage:
  #    $(basename $0) { operation } [infrastructure_folder]
  #      options:
  #      - operation: { on | off }
  #      - infrastructure_folder: default=infrastructure 
  info "[cdk_infra|in] ($1) ($2)"

  local DEFAULT_INFRA_DIR=infrastructure

  [ -z $1 ] && usage
  [ "$1" != "on" ] && [ "$1" != "off" ]&& [ "$1" != "bootstrap" ] && usage
  local operation="$1"
  local tf_dir="${DEFAULT_INFRA_DIR}"
  if [ ! -z $2 ]; then
    local tf_dir="$2"
  else
    info "[cdk_infra] assuming default infra folder: ${DEFAULT_INFRA_DIR}"
  fi

  if [ ! -z $3 ]; then
    local stacks="$3"
  else
    local stacks="--all"
  fi

  _pwd=`pwd`
  cd "$tf_dir"

  if [ "$operation" == "on" ]; then
    cdk synth "$stacks"
    [ "$?" -ne "0" ] && err "[infra] couldn't synth" && cd "$_pwd" && exit 1
    cdk deploy "$stacks" --require-approval=never -v --debug
    [ "$?" -ne "0" ] && err "[infra] couldn't deploy" && cd "$_pwd" && exit 1
  elif [ "$operation" == "off" ]; then
    cdk destroy "$stacks" --force
    [ "$?" -ne "0" ] && err "[infra] couldn't destroy" && cd "$_pwd" && exit 1
  elif [ "$operation" == "bootstrap" ]; then
    cdk bootstrap --force --termination-protection false
    [ "$?" -ne "0" ] && err "[infra] couldn't bootstrap" && cd "$_pwd" && exit 1
  fi

  cd "$_pwd"
  info "[cdk_infra|out]"
}

############################
#   name: cdk_setup
#   purpose: runs 'npm install' in the CDK infrastructure directory to install project dependencies
#   parameters: $1 (infrastructure folder path, default: infrastructure)
#   requires: npm
############################

cdk_setup()
{
    info "[cdk_setup|in] ($1)"
    local DEFAULT_INFRA_DIR=infrastructure

    local tf_dir="${DEFAULT_INFRA_DIR}"
    if [ ! -z $1 ]; then
      local tf_dir="$1"
    else
      info "[cdk_setup] assuming default infra folder: ${DEFAULT_INFRA_DIR}"
    fi
    _pwd=`pwd`
    cd "$tf_dir"
    npm install
    result="$?"
    cd "$_pwd"
    [ "$result" -ne "0" ] && err "[cdk_setup|out]  => ${result}" && exit 1
    info "[cdk_setup|out] => ${result}"
}
