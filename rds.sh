#!/bin/bash
set -a

for nv in $@ ; do
  eval "$nv" 2> /dev/null
done

# Perform cloudformation stack actions to create/update an empty aurora-mysql rds database.
rds() {
  [ -z "$STACK_NAME" ] && STACK_NAME="kuali-aurora-mysql-rds"
  [ -z "$PASSWORD_URL" ] && PASSWORD_URL="s3://kuali-research-ec2-setup/rds/password1"

  case "$task" in
    create)
      action="create-stack"
      ;;
    update)
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
  local password="$(aws s3 cp $PASSWORD_URL -)"
  cat <<-EOF > rds-stack.sh
  aws \
    cloudformation $action \
    --stack-name $STACK_NAME \
    $([ $rdstask != 'create' ] && echo '--no-use-previous-template') \
    --template-body file://./kuali-aurora-mysql-rds.yml \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters '[
      { 
        "ParameterKey" : "DatabasePassword",
        "ParameterValue" : "$password"
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
  --stack-name kuali-aurora-mysql-rds \
  --query 'Stacks[].Outputs[].[OutputKey, OutputValue]' \
  --output text)";

  # Apply default values to missing parameters.
  [ -z "$KC_DB_NAME" ] && KC_DB_NAME="kualidb"
  [ -z "$KC_DB_NAME" ] && KC_DB_NAME="$DBName"
  [ -z "$KC_DB_USERNAME" ] && KC_DB_USERNAME="kcusername"
  [ -z "$KC_DB_USERNAME" ] && KC_DB_USERNAME="$DBUsername"
  [ -z "$KC_DB_PORT" ] && KC_DB_PORT="3306"
  [ -z "$KC_DB_PORT" ] && KC_DB_PORT="$Port"
  [ -z "$DB_HOST" ] && DB_HOST="$ClusterEndpoint"
  [ -z "$KC_REPO_URL" ] && KC_REPO_URL="https://github.com/bu-ist/kuali-research.git"
  [ -z "$KC_DB_PASSWORD" ] && KC_DB_PASSWORD="s3://kuali-research-ec2-setup/rds/password1"
  [ -z "$KC_PROJECT_BRANCH" ] && KC_PROJECT_BRANCH="bu-master"
  [ -z "$WORKING_DIR" ] && WORKING_DIR="$(pwd)"
  [ -z "$INSTALL_DEMO_FILES" ] && INSTALL_DEMO_FILES='true'

  # If the password is actually an s3 url to a file, the password is in that file.
  if [ "${KC_DB_PASSWORD:0:5}" == "s3://" ] ; then
    KC_DB_PASSWORD="$(aws s3 cp $KC_DB_PASSWORD -)"
  fi

  sh setup_files/install_kuali_db.sh
}


task="$1"
shift

case "$task" in
  populate) populate $@ ;;
  *) rds $@ ;;
esac