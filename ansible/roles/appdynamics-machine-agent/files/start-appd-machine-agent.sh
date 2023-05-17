#!/bin/bash

# Script to start AppDynamics machine agent
# There are a number of environment properties that first need to be obtained.
# The script downlaods any properties files from the corresponding S3 config bucket and extracts all env vars with an APPDYNAMICS_ prefix

exec > >(tee -ai ~/appd-ma-start-up.log) 2>&1
echo " ~~~~~~~~~ Start AppDynamics machine agent wrapper script: `date -u "+%F %T"`"
set -a

# set up variables based on aws metadata etc
. set-aws-vars.sh

# Check S3 and Config can be reached
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. "
  exit 1
fi

MACHINE_AGENT_HOME=/home/ec2-user/machineagent

# Create a tmp directory to store downloaded config
mkdir -p ${MACHINE_AGENT_HOME}/tmp-s3-config
cd ${MACHINE_AGENT_HOME}/tmp-s3-config

# Download all properties files
aws s3 cp ${CONFIG_BASE_PATH}/ ./  --recursive --exclude "*" --include "*.properties"
aws s3 cp ${CONFIG_BASE_PATH}/${APP_INSTANCE_NAME}/ ./ --recursive --exclude "*" --include "*.properties"

# Extract the AppD env vars - excluding APPDYNAMICS_AGENT_APPLICATION_NAME and APPDYNAMICS_AGENT_TIER_NAME
grep "^APPDYNAMICS_" *.properties | grep -v APPDYNAMICS_AGENT_APPLICATION_NAME | grep -v APPDYNAMICS_AGENT_TIER_NAME > appd.env

# Source the env vars
. ./appd.env

# Clean up by removing anything we have downloaded
rm *.properties appd.env

# Start the agent using nohup
cd ${MACHINE_AGENT_HOME}
nohup $MACHINE_AGENT_HOME/jre/bin/java -jar $MACHINE_AGENT_HOME/machineagent.jar > /dev/null 2>&1 &