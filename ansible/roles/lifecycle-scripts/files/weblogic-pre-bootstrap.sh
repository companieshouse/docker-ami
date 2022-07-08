#!/bin/bash

exec > >(tee -ai ~/wl-pre-bootstrap.log) 2>&1
echo " ~~~~~~~~~ Starting initial steps pre-bootstrap : `date -u "+%F %T"`"
set -a

echo Load variables from AWS
. $(dirname $0)/set-aws-vars.sh

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
for FILESTORE in FileStore1 FileStore2 FileStore3 FileStore4
do
  cd ${INSTANCE_DIR}/${APP_INSTANCE_NAME}/running-servers/FileStores/JMS/${FILESTORE}
  for file in $( ls -1 *DAT )
  do
    mv $file $file.bak
    cp $file.bak $file
  done
done

set +a

### END
echo " ~~~~~~~~~ Completed initial steps pre-bootstrap : `date -u "+%F %T"`"