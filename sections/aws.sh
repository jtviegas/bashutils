##########################################
#######     ------- aws -------    #######
##########################################

############################
#   name: aws_find_kms_alias
#   purpose: checks whether a KMS key alias exists in the current AWS account
#   parameters: $1 (full alias name, e.g. alias/my-key)
#   returns: 0 if the alias exists, 1 if not found
#   requires: aws, jq
############################
aws_find_kms_alias(){
  echo "[aws_find_kms_alias|in] ($1)"

  [ -z $1 ] && err "[aws_find_kms_alias] missing argument ALIAS" && exit 1
  local ALIAS="$1"
  result=1

  local alias_resource=$(aws kms list-aliases | jq -r ".\"Aliases\" | .[] | select(.AliasName == \"$ALIAS\") | .AliasName")
  echo "[aws_find_kms_alias] alias_resource: ${alias_resource}"
  if [ "$alias_resource" != "" ]; then
    result=0
  fi

  echo "[aws_find_kms_alias|out] => ${result}"
  return ${result}
}

############################
#   name: aws_get_cloudfront_cidr
#   purpose: retrieves the CIDR entries from the CloudFront origin-facing managed prefix list and writes them as JSON to a file
#   parameters: $1 (output file path)
#   requires: aws, jq
############################

aws_get_cloudfront_cidr(){
  info "[aws_get_cloudfront_cidr|in] ($1)"

  [ -z $1 ] && err "[aws_get_cloudfront_cidr] missing argument OUTPUT_FILE" && exit 1
  local OUTPUT_FILE="$1"

  local prefix_list_id=$(aws ec2 describe-managed-prefix-lists | jq -r ".\"PrefixLists\" | .[] | select(.PrefixListName == \"com.amazonaws.global.cloudfront.origin-facing\") | .PrefixListId")
  local outputs=$(aws ec2 get-managed-prefix-list-entries --prefix-list-id "$prefix_list_id" --output json)
  echo $outputs | jq -r ".\"Entries\"" > "$OUTPUT_FILE"

  result="$?"
  [ "$result" -ne "0" ] && err "[aws_get_cloudfront_cidr|out]  => ${result}" && exit 1
  info "[aws_get_cloudfront_cidr|out] => ${result}"
}

############################
#   name: aws_set_profile
#   purpose: configures a named AWS CLI profile with static credentials and region using 'aws configure'
#   parameters: $1 (profile name), $2 (AWS access key ID), $3 (AWS secret access key),
#               $4 (AWS region, e.g. eu-west-1), $5 (output format, default: json)
#   requires: aws
############################

aws_set_profile(){
  info "[aws_set_profile|in] ($1, $2, ${3:0:5}, $4, $5)"
  local _pwd
  _pwd=$(pwd)

  [ -z $1 ] && err "[aws_set_profile] missing argument PROFILE" && return 1
  local PROFILE="$1"
  [ -z $2 ] && err "[aws_set_profile] missing argument KEY" && return 1
  local KEY="$2"
  [ -z $3 ] && err "[aws_set_profile] missing argument SECRET" && return 1
  local SECRET="$3"
  [ -z $4 ] && err "[aws_set_profile] missing argument REGION" && return 1
  local REGION="$4"

  if [ ! -z $5 ]; then
    local OUTPUT="$5"
  else
    local OUTPUT="json"
  fi

  aws configure --profile $PROFILE set region $REGION \
    && aws configure --profile $PROFILE set output $OUTPUT \
    && aws configure --profile $PROFILE set aws_secret_access_key $SECRET \
    && aws configure --profile $PROFILE set aws_access_key_id $KEY

  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[aws_set_profile|out]  => ${result}" && exit 1
  info "[aws_set_profile|out] => ${result}"
}
