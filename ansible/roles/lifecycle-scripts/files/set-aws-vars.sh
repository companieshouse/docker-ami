#!/bin/bash
### Script to set variables used by bootstrap and similar scripts
### Requires values to be supplied as tags on the EC2 instance where it runs:
###   ApplicationType  (the name of the application type - e.g. cics or chips etc)
###   app-instance-name  (the name of the application instance type - e.g. cics1 or chips-ef-batch1 etc)
###   config-base-path (the S3 path to where the config is stored - e.g. s3://shared-services.eu-west-2.configs.ch.gov.uk/cic-configs/development etc)
### The tags are defined in terraform code and set as values on the launch configuration that is used by the Auto Scaling Group to create EC2 instances.

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
