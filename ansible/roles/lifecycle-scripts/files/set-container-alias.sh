#!/bin/bash
### Script to set a Docker container alias in the .bashrc file for running bash
### in a specific Docker service container as a specific user.
### This script can be run on EC2 instance startup in a similar way to the bootstrap script.
###
### This takes 3 parameters:
### 1. ALIAS: The alias name to be set
### 2. SERVICE: The Docker service name (e.g., build, batch, etc.)
### 3. USER: The user to use to enter the container

LOG_FILE=~/setalias.log

exec > >(tee -ai ${LOG_FILE}) 2>&1
echo " ~~~~~~~~~ Setting container alias $1 $2 $3: `date -u "+%F %T"`"

# Check there are 3 params supplied
if [ $# -ne 3 ]; then
    echo "Expecting 3 params: ALIAS SERVICE USER"
    echo "E.g.: set-container-alias.sh oltp oltp-batch oltp"
    echo "would result in the alias alias oltp='docker exec -it -u oltp \${APP_INSTANCE_NAME}-oltp-batch-1 bash' being added to .bashrc"
    # exit with error code 0 as this is not a failure that should stop the instance from starting
    exit 0
fi
ALIAS=$1
SERVICE=$2
USER=$3

# set up variables based on aws metadata etc
. set-aws-vars.sh
echo "alias ${ALIAS}='docker exec -it -u ${USER} ${APP_INSTANCE_NAME}-${SERVICE}-1 bash'" >> .bashrc

echo " ~~~~~~~~~ Finished setting container alias : `date -u "+%F %T"`"
