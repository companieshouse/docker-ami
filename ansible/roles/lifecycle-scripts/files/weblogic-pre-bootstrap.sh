#!/bin/bash

exec > >(tee -ai ~/wl-pre-bootstrap.log) 2>&1
echo " ~~~~~~~~~ Starting initial steps pre-bootstrap : `date -u "+%F %T"`"
set -a

echo Load variables from AWS
NFS_MOUNT_LOCATION="/mnt/nfs"
EC2_REGION=$( ec2-metadata -z | awk '{print $2}' | sed 's/[a-z]$//' )  #eu-west-2

# Get EC2_INSTANCE_ID  #029a4768b982f1c1d
EC2_INSTANCE_ID=$( ec2-metadata -i |  awk -F'[: ]' '{print $3}' )
echo "EC2_INSTANCE_ID=${EC2_INSTANCE_ID}" 

# Get ApplicationType TAG from EC2 instance   #chips
APP_NAME=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep ApplicationType|  awk '{print $5}' | tr '[:upper:]' '[:lower:]' )
echo "APP_NAME=${APP_NAME}" 

INSTANCE_DIR=${NFS_MOUNT_LOCATION}/${APP_NAME}
echo "INSTANCE_DIR=${INSTANCE_DIR}"  #/mnt/nfs/chips

# Get app-instance-name TAG from EC2 instance  APP_INSTANCE_NAME=chips-users-rest0
APP_INSTANCE_NAME=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${EC2_INSTANCE_ID}" --region ${EC2_REGION} --output text|grep app-instance-name|  awk '{print $5}' )
echo "APP_INSTANCE_NAME=${APP_INSTANCE_NAME}"


echo delete lok file then move and copy back all servers data store default DAT file
for SERVER in wladmin wlserver1 wlserver2 wlserver3 wlserver4
do
  rm ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers/${SERVER}/tmp/${SERVER}.lok
  cd ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers/${SERVER}/data/store/default
  for file in $( ls -1 *DAT )
  do
    mv $file $file.bak
    cp $file.bak $file
  done
done

echo move and copy back managed server FileStore
for SERVER in wlserver1 wlserver2 wlserver3 wlserver4
do
  cd ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers/FileStores/JMS/FileStore1
  for file in $( ls -1 *DAT )
  do
    mv $file $file.bak
    cp $file.bak $file
  done
done

set +a

### END
echo " ~~~~~~~~~ Completed initial steps pre-bootstrap : `date -u "+%F %T"`"