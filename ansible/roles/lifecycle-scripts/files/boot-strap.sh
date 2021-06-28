#!/bin/bash
### COMMENTS  #############################
# I am a script to start WebLogic Admin and Managed Servers using Docker Compose.  
# I require values passed in from AMI, terraform, build, etc.  
#   so I can retrieve correct config, build server directory structure,  pass versions to docker-compose 
# Required meta data: 
# - Code versions  
# - Shared config buckert address
# - Environment (Live, Stage, Dev)
# - Instance (Server1 or 2, etc.)

LOG=start-up.log
echo " ~~~~~~ Starting Docker Compose wrapper script: `date -u "+%F %T"`" > $LOG
set -a

# Hard coded for now
INSTANCE_DIR="instance-dir"

# Get WL_INSTANCE_NAME - what are we : server1, server2, EF, etc. ?
# Get EC2 instance id
EC2_INSTANCE_ID=`ec2-metadata -i |  awk -F'[: ]' '{print $3}'`
echo "EC2_INSTANCE_ID=${EC2_INSTANCE_ID}" | tee -a $LOG

# Get TAG passed in via AMI, terraform, build, etc 
APP_INSTANCE_NAME=`aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region eu-west-2 --output text|grep app-instance-name|  awk '{print $5}'`
echo "APP_INSTANCE_NAME=${APP_INSTANCE_NAME}" | tee -a $LOG

# Get confog base path
CONFIG_BASE_PATH=`aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region eu-west-2 --output text|grep config-base-path|  awk '{print $5}'`
echo "CONFIG_BASE_PATH=${CONFIG_BASE_PATH}" | tee -a $LOG

# Check S3 and Config can be reached 
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. " | tee -a $LOG
  exit 1
fi

# create server instance directory 
mkdir -p ${INSTANCE_DIR}/${APP_INSTANCE_NAME}

# Copy properties, docker-compose file, app versions, etc. recursively to current directory
aws s3 cp ${CONFIG_BASE_PATH}/ ./${INSTANCE_DIR}/${APP_INSTANCE_NAME} --recursive --exclude "*/*"
aws s3 cp ${CONFIG_BASE_PATH}/${APP_INSTANCE_NAME} ./${INSTANCE_DIR}/${APP_INSTANCE_NAME} --recursive --exclude "*/*"

# Get and source application versions to use for Docker Compose 
# CIC_APACHE_IMAGE
# CIC_APP_IMAGE
. ./${INSTANCE_DIR}/${APP_INSTANCE_NAME}/app-image-versions

echo "`env`" | grep IMAGE | tee -a $LOG

# Log in to ECR ??? values passed in or hard coded ???
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 169942020521.dkr.ecr.eu-west-2.amazonaws.com
set +a

### RUN DOCKER COMPOSE
echo "Starting docker compose file " | tee -a $LOG
docker-compose -f ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/docker-compose.yml up -d