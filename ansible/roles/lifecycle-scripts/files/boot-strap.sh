#!/bin/bash

### Script to start Docker containers using Docker Compose.
### Requires values to be supplied as tags on the EC2 instance where it runs:
###   ApplicationType  (the name of the application type - e.g. cics or chips etc)
###   app-instance-name  (the name of the application instance type - e.g. cics1 or chips-ef-batch1 etc) - if a parameter is supplied to this script, it will override the value obtained from tags.
###   config-base-path (the S3 path to where the config is stored - e.g. s3://shared-services.eu-west-2.configs.ch.gov.uk/cic-configs/development etc)
### The tags are defined in terraform code and set as values on the launch configuration that is used by the Auto Scaling Group to create EC2 instances.

LOG_FILE=~/start-up.log
# Use a dedicated log if $1 supplied
if [ ! -z  "$1" ]; then
  LOG_FILE=~/$1-start-up.log
fi

exec > >(tee -ai ${LOG_FILE}) 2>&1
echo " ~~~~~~~~~ Starting Docker Compose wrapper script: `date -u "+%F %T"`"
set -a

# set up variables based on aws metadata etc
. set-aws-vars.sh

# Check S3 and Config can be reached
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. "
  exit 1
fi

# Set APP_INSTANCE_NAME env var to $1 if supplied
if [ ! -z  "$1" ]; then
  APP_INSTANCE_NAME=$1
fi

# Provide uppercase APP_INSTANCE_NAME
APP_INSTANCE_NAME_UPPER="${APP_INSTANCE_NAME^^}"

# create server instance directory
mkdir -p ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers
cd ${INSTANCE_DIR}/${APP_INSTANCE_NAME}

# Copy properties, docker-compose file, app versions, etc. recursively to current directory
aws s3 cp ${CONFIG_BASE_PATH}/ ./ --recursive --exclude "*/*"
aws s3 cp ${CONFIG_BASE_PATH}/${APP_INSTANCE_NAME}/ ./ --recursive

# Process any properties files to lookup parameter store values
lookup-secrets.sh

# Get and source application versions to use for Docker Compose
# Also soruces any additional vars set in app-image-versions, such as APP_INSTANCE_NUMBER
. app-image-versions
echo "`env`" | grep IMAGE

# Get ECR Repo details and log into ECR
AWS_ECR_REPO_DOMAIN=amazonaws.com
# Loop through each distinct AWS repo and login
for AWS_ECR_REPO in $( grep ${AWS_ECR_REPO_DOMAIN} app-image-versions | sed 's/.*=\(.*\)\/.*/\1/' | uniq )
do
  AWS_ECR_REGION=$( echo ${AWS_ECR_REPO/.${AWS_ECR_REPO_DOMAIN}} | sed 's/.*\.//' )
  echo Logging into: ${AWS_ECR_REGION} ${AWS_ECR_REPO}
  aws ecr get-login-password --region ${AWS_ECR_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_REPO}
done

set +a

### Prune docker images
echo "Pruning all docker images not currently in use ..."
docker image prune -a --force

### RUN DOCKER COMPOSE
echo "Starting docker compose file ..."
docker-compose up -d
