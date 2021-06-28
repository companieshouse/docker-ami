#!/bin/bash

### Script to start WebLogic Admin and Managed Servers using Docker Compose.  
### Requires values passed in from AMI and AWS cli commands   
### Function is to retrieve correct config, build server directory structure, pass App versions to docker-compose, etc. 
### Required meta data: 
### - Code versions  
### - Shared config buckert address
### - Environment (Live, Stage, Dev)
### - Instance (Server1 or 2, etc.)

LOG=start-up.log
echo " ~~~~~~ Starting Docker Compose wrapper script: `date -u "+%F %T"`" > $LOG
set -a

# WL Server parent directory name 
INSTANCE_DIR="instance-dir"
EC2_REGION=$( ec2-metadata -z | awk '{print $2}' | sed 's/[a-z]$//' )

# Get EC2_INSTANCE_ID - example server1, server2, etc.
EC2_INSTANCE_ID=$( ec2-metadata -i |  awk -F'[: ]' '{print $3}' )
echo "EC2_INSTANCE_ID=${EC2_INSTANCE_ID}" | tee -a $LOG

# Get TAG passed in via AMI, terraform, build, etc 
APP_INSTANCE_NAME=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep app-instance-name|  awk '{print $5}' )
echo "APP_INSTANCE_NAME=${APP_INSTANCE_NAME}" | tee -a $LOG

# Get confog base path
CONFIG_BASE_PATH=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep config-base-path|  awk '{print $5}' )
echo "CONFIG_BASE_PATH=${CONFIG_BASE_PATH}" | tee -a $LOG

# Check S3 and Config can be reached 
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. " | tee -a $LOG
  exit 1
fi

# create server instance directory 
mkdir -p ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers
cd ${INSTANCE_DIR}/${APP_INSTANCE_NAME}
# Copy properties, docker-compose file, app versions, etc. recursively to current directory
aws s3 cp ${CONFIG_BASE_PATH}/ ./ --recursive --exclude "*/*"
aws s3 cp ${CONFIG_BASE_PATH}/${APP_INSTANCE_NAME}/ ./ --recursive --exclude "*/*"

# Get and source application versions to use for Docker Compose 
# CIC_APACHE_IMAGE
# CIC_APP_IMAGE
. app-image-versions

echo "`env`" | grep IMAGE | tee -a $LOG

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

### RUN DOCKER COMPOSE
echo "Starting docker compose file " | tee -a $LOG
docker-compose up -d