#!/bin/bash

### Script to start Docker containers using Docker Compose.
### Requires values to be supplied as tags on the EC2 instance where it runs:
###   ApplicationType  (the name of the application type - e.g. cics or chips etc)
###   app-instance-name  (the name of the application instance type - e.g. cics1 or chips-ef-batch1 etc)
###   config-base-path (the S3 path to where the config is stored - e.g. s3://shared-services.eu-west-2.configs.ch.gov.uk/cic-configs/development etc)
### The tags are defined in terraform code and set as values on the launch configuration that is used by the Auto Scaling Group to create EC2 instances.

exec > >(tee -ai ~/start-up.log) 2>&1
echo " ~~~~~~~~~ Starting Docker Compose wrapper script: `date -u "+%F %T"`"
set -a

NFS_MOUNT_LOCATION="/mnt/nfs"
EC2_REGION=$( ec2-metadata -z | awk '{print $2}' | sed 's/[a-z]$//' )

# Get EC2_INSTANCE_ID
EC2_INSTANCE_ID=$( ec2-metadata -i |  awk -F'[: ]' '{print $3}' )
echo "EC2_INSTANCE_ID=${EC2_INSTANCE_ID}"

# Get ApplicationType TAG from EC2 instance
APP_NAME=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep ApplicationType|  awk '{print $5}' | tr '[:upper:]' '[:lower:]' )
echo "APP_NAME=${APP_NAME}"

INSTANCE_DIR=${NFS_MOUNT_LOCATION}/${APP_NAME}
echo "INSTANCE_DIR=${INSTANCE_DIR}"

# Get app-instance-name TAG from EC2 instance
APP_INSTANCE_NAME=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep app-instance-name|  awk '{print $5}' )
echo "APP_INSTANCE_NAME=${APP_INSTANCE_NAME}"

# Get config base path
CONFIG_BASE_PATH=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep config-base-path|  awk '{print $5}' )
echo "CONFIG_BASE_PATH=${CONFIG_BASE_PATH}"

# Check S3 and Config can be reached
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. "
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

### RUN DOCKER COMPOSE
echo "Starting docker compose file ..."
docker-compose up -d