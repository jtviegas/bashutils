##########################################
####### ------- terraform -------  #######
##########################################

############################
#   name: terraform_autodeploy
#   purpose: runs a full Terraform deployment (init → plan → apply --auto-approve) in the given folder
#   parameters: $1 (path to the folder containing Terraform configuration files)
#   requires: terraform
############################
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

############################
#   name: terraform_autodestroy
#   purpose: runs 'terraform destroy --auto-approve' in the given folder to tear down all managed infrastructure
#   parameters: $1 (path to the folder containing Terraform configuration files)
#   requires: terraform
############################

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
