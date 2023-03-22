#!/bin/bash

### Script to start multiple Docker environments that  is intended for use where there are multiple envionments on a single EC2 instance.
### Each environment is defined on S3 within a sub-folder under the config-base-path
### Requires values to be supplied as tags on the EC2 instance where it runs:
###   ApplicationType  (the name of the application type - e.g. cics or chips etc)
###   config-base-path (the S3 path to where the config is stored - e.g. s3://shared-services.eu-west-2.configs.ch.gov.uk/cic-configs/development etc)
### The tags are defined in terraform code and set as values on the launch configuration/template that is used by the Auto Scaling Group to create EC2 instances.

echo " ~~~~~~~~~ Starting Docker Compose multi wrapper script: `date -u "+%F %T"`"
set -a

# set up variables based on aws metadata etc
. set-aws-vars.sh

# Check S3 and Config can be reached
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. "
  exit 1
fi

# Get a list of environments by listing the sub-folders under ${CONFIG_BASE_PATH}
ENVIRONMENTS=$(aws s3 ls ${CONFIG_BASE_PATH}/ | grep PRE | awk '{print $2}' | tr -d '/')

for ENVIRONMENT in ${ENVIRONMENTS}
do
  ./bootstrap ${ENVIRONMENT} &
done


