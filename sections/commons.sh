##########################################
#######  ------- commons -------   #######
##########################################

############################
#   name: commands
#   purpose: prints a quick-reference cheat sheet of commonly used commands covering:
#            Python virtualenv/Jupyter, AWS CDK (TypeScript), AWS CLI, and git configuration
#   parameters: none
############################
commands() {
  cat <<EOM

  handy commands:

  python -m venv .venv                                             create virtual environment
  jupyter-notebook --log-level=40 --no-browser                            starts jupyter server
  cdk init app --language typescript                                      create new cdk app on typescript
  npm run build                                                           compile typescript to js
  npm run watch                                                           watch for changes and compile
  npm run test                                                            perform the jest unit tests
  git config user.email "$JTV_GITHUB_EMAIL"                               set local git config email
  aws-cdk
    cdk init app --language typescript                                    create new cdk app on typescript
    cdk deploy                                                            deploy this stack to your default AWS account/region
    cdk diff                                                              compare deployed stack with current state
    cdk synth                                                             emits the synthesized CloudFormation template
  aws
    aws cloudformation delete-stack --stack-name <STACKNAME>              delete stack to later recreate with bootstrap (see https://stackoverflow.com/questions/71280758/aws-cdk-bootstrap-itself-broken/71283964#71283964)
    aws configure sso --profile nn --no-browser                           configure sso
    export AWS_PROFILE=nn                                                 set current environment profile
    aws sts get-caller-identity                                           check current session
    aws sts get-caller-identity --profile <PROFILE>                       display session profile info
    aws lambda invoke --function-name FUNCTION_NAME out --log-type Tail 

EOM
}
