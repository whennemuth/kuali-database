#!/bin/bash
set -a

for nv in $@ ; do
  eval "$nv" 2> /dev/null
done

[ -z "$STACK_NAME" ] && STACK_NAME="kuali-aurora-mysql-rds"

# Perform cloudformation stack actions to create/update an empty aurora-mysql rds database.
rds() {

  case "$task" in
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
    recreate)
      aws cloudformation delete-stack --stack-name $STACK_NAME
      if stackIsDeleted ; then
        task='create'
        setPassword
        action='create-stack'
      fi
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
    $([ "$task" != 'create' ] && echo '--no-use-previous-template') \
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

# If the password is actually an s3 url to a kc-config.xml file, extract with the password from it.
setPassword() {
  [ -z "$DB_PASSWORD" ] && DB_PASSWORD="s3://kuali-research-ec2-setup/sb/kuali/main/config/kc-config-rds.xml"
  if [ "${DB_PASSWORD:0:5}" == "s3://" ] ; then
    DB_PASSWORD="$(getKcConfigParm 'datasource.password' $DB_PASSWORD)"
  fi
  if [ -z "$DB_PASSWORD" ] ; then
    echo "ERROR! DB_PASSWORD is empty!!!"
    exit 1
  fi
}

# Echo the value of a parameter in a kc-config.xml file stored in s3
getKcConfigParm() {
  parmName="$1"
  kcConfig="$2"
  aws s3 cp $kcConfig - | grep '<param name=\"'$parmName'\"' | grep -oP '>(.*)<' | sed 's/[<>]//g'
}

# Once the delete-stack command has been issued, keep checking for actual deletion to complete (give up after 30 minutes).
stackIsDeleted() {
  local i=1
  while ((i<360)) ; do
    STACK_STATUS="$(aws cloudformation describe-stacks --stack-name $STACK_NAME | grep 'StackStatus')"
    if [ -z "$STACK_STATUS" ] ; then
      echo "$STACK_NAME deleted!!!"
      DELETED="true"
      break;
    else
      echo "$STACK_STATUS"
    fi
    ((i+=1))
    sleep 5
  done
  if [ -n "$STACK_STATUS" ] ; then
    echoAndLog "ERROR! Half an hour has expired and the stack is still not deleted!"
    return 1
  fi
}



task="$1"
shift

case "$task" in
  populate) populate $@ ;;
  *) rds $@ ;;
esac