#!/bin/bash
set -a

for nv in $@ ; do
  eval "$nv" 2> /dev/null
done

[ -z "$STACK_NAME" ] && STACK_NAME="kuali-aurora-mysql-rds"

# Perform cloudformation stack actions to create/update an empty aurora-mysql rds database.
rds() {

  rdstask="$1"
  shift

  case "$rdstask" in
    create)
      setPassword
      action="create-stack"
      ;;
    update)
      setPassword
      action="update-stack"
      ;;
    delete)
      aws cloudformation delete-stack --stack-name $STACK_NAME
      return 0
      ;;
    validate)
      aws cloudformation validate-template --template-body "file://./kuali-aurora-mysql-rds.yml"
      return 0
      ;;
  esac

  # create or update stack
  cat <<-EOF > rds-stack.sh
  aws \
    cloudformation $action \
    --stack-name $STACK_NAME \
    $([ "$rdstask" != 'create' ] && echo '--no-use-previous-template') \
    --template-body file://./kuali-aurora-mysql-rds.yml \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters '[
      { 
        "ParameterKey" : "DatabasePassword",
        "ParameterValue" : "$DB_PASSWORD"
      }
    ]'
EOF

  cat rds-stack.sh
  sh rds-stack.sh
}

# Build and populate an empty mysql database with a kuali-research schema.
populate() {
  
  # Get the outputs of the cloudformation stack in which the mysql rds database was created.
  #   - DBName
  #   - DBUsername
  #   - DBPort
  #   - ClusterEndpoint
  #   - ReaderEndpoint
  #   - MysqlCommandLine
  while read -r line; do
    name="$(echo "$line" | cut -f1)"
    value="$(echo "$line" | cut -f2-)"
    echo "$name=\"$value\""
    eval "$name=\"$value\""
  done <<< "$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[].Outputs[].[OutputKey, OutputValue]' \
    --output text)";

  [ -z "$DB_HOST" ] && DB_HOST="$ClusterEndpoint"
  if [ -z "$DB_HOST" ] ; then
    echo "ERROR! Cannot determine database host address."
    exit 1
  fi

  # Apply default values to missing parameters.
  [ -z "$DB_NAME" ] && DB_NAME="$DBName"
  [ -z "$DB_NAME" ] && DB_NAME="kualidb"
  [ -z "$DB_USERNAME" ] && DB_USERNAME="$DBUsername"
  [ -z "$DB_USERNAME" ] && DB_USERNAME="kcusername"
  [ -z "$DB_PORT" ] && DB_PORT="$Port"
  [ -z "$DB_PORT" ] && DB_PORT="3306"
  [ -z "$KC_REPO_URL" ] && KC_REPO_URL="https://github.com/bu-ist/kuali-research.git"
  [ -z "$KC_PROJECT_BRANCH" ] && KC_PROJECT_BRANCH="master"
  [ -z "$WORKING_DIR" ] && WORKING_DIR="$(pwd)"
  [ -z "$INSTALL_DEMO_FILES" ] && INSTALL_DEMO_FILES='true'

  setPassword

  sh setup_files/install_kuali_db.sh
}

# If the password is actually an s3 url to a file, the password is in that file.
setPassword() {
  [ -z "$DB_PASSWORD" ] && DB_PASSWORD="s3://kuali-research-ec2-setup/rds/password1"
  if [ "${DB_PASSWORD:0:5}" == "s3://" ] ; then
    DB_PASSWORD="$(aws s3 cp $DB_PASSWORD -)"
  fi
  if [ -z "$DB_PASSWORD" ] ; then
    echo "ERROR! DB_PASSWORD is empty!!!"
    exit 1
  fi
}


task="$1"
shift

case "$task" in
  populate) populate $@ ;;
  *) rds $@ ;;
esac