#!/bin/bash

### Script to update cronab within the batch container based on crontab.txt file stored in S3 in <image-name>-cron subdir
### Relies on docker bind mount for crontab dir e.g. /mnt/nfs/chips/chips-ef-batch0/chips-weblogic-batch-cron as <home-dir>/cron
### Requires values to be supplied as tags on the EC2 instance where it runs:
###   ApplicationType  (the name of the application type - e.g. cics or chips etc)
###   app-instance-name  (the name of the application instance type - e.g. cics1 or chips-ef-batch1 etc)
###   config-base-path (the S3 path to where the config is stored - e.g. s3://shared-services.eu-west-2.configs.ch.gov.uk/cic-configs/development etc)
### The tags are defined in terraform code and set as values on the launch configuration that is used by the Auto Scaling Group to create EC2 instances.

exec > >(tee -ai ~/updatecron.log) 2>&1
echo " ~~~~~~~~~ Starting cron update script: `date -u "+%F %T"`"

# set up variables based on aws metadata etc
. set-aws-vars.sh

# Check S3 and Config can be reached
aws s3 ls ${CONFIG_BASE_PATH} >/dev/null

if (( $? != 0 )) ; then
  echo "ERROR - S3 or Config can not be found. Exit. "
  exit 1
fi

# Copy config subdirectory content (i.e. crontab) recursively to matching directory
aws s3 cp ${CONFIG_BASE_PATH}/${APP_INSTANCE_NAME}/ ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/ --recursive

for CRON_DIR in ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/*-cron; do
  echo "~~~ Cron directory found: ${CRON_DIR}"
  CONTAINER_NAME=$(docker ps --filter "volume=$CRON_DIR" --format "{{.Names}}")
  if [ $(wc -w <<< $CONTAINER_NAME) -eq 1 ]; then
    CONTAINER_USER=$(basename $CRON_DIR | awk -F- '{print $2}')
    echo "Updating cron for user $CONTAINER_USER in container $CONTAINER_NAME"
    docker exec -u $CONTAINER_USER -it $CONTAINER_NAME bash -c "crontab ./cron/crontab.txt"
    echo "Confirming update - current first line of loaded crontab is:"
    docker exec -u $CONTAINER_USER -it $CONTAINER_NAME bash -c "crontab -l | head -1"
  elif [ $(wc -w <<< $CONTAINER_NAME) -gt 1 ]; then
    echo "ERROR: Multiple containers found that mount this cron dir, skipping cron update:"
    echo "$CONTAINER_NAME"
  else
    echo "WARNING: No container found that mounts ${CRON_DIR}"
  fi
done
