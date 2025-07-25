#!/bin/bash

### Script to load cached Docker images from tar files in a shared NFS image-cache directory.
###
### This loads the latest locally built images (that will not have been published to ECR)
### after an EC2 instance restart/recreation.
### This is also used to load images prior to bootstrap on environments with multiple EC2 instances,
### where the images would not otherwise be available to additonal instances.
### The tar files are located in the NFS INSTANCE_DIR/image-cache directory and
### all images matching the pattern *-<environment-name>-*.tar will be loaded.

LOG_FILE=~/load-cached-images.log

exec > >(tee -ai ${LOG_FILE}) 2>&1
echo " ~~~~~~~~~ Starting loading of cached images: `date -u "+%F %T"`"

# set up variables based on aws metadata etc
. set-aws-vars.sh

IMAGE_CACHE_DIR=${INSTANCE_DIR}/image-cache
cd ${IMAGE_CACHE_DIR}

# Derive a consistent environment name
# APP_INSTANCE_NAME could be a name like waldorf for a single instance environment,
# or a name like chips-waldorf0 or chips-waldorf1 for a multi-instance environment
# We need an ENV_NAME var that is the same for both single and multi-cluster
# environments - i.e. just waldorf for those examples.
if [[ ${APP_INSTANCE_NAME} == ${APP_NAME}-* ]]; then
    # Strip off the prefix
    ENV_NAME=${APP_INSTANCE_NAME#${APP_NAME}-}
    # Strip off last character
    ENV_NAME=${ENV_NAME::-1}
else
    ENV_NAME=${APP_INSTANCE_NAME}
fi
echo "ENV_NAME=${ENV_NAME}"

for CACHED_IMAGE in $(ls -1 *-${ENV_NAME}-*.tar);
do
    echo "Loading image tar: ${CACHED_IMAGE}"
    docker load -i ${CACHED_IMAGE}
done

echo " ~~~~~~~~~ Finished loading of cached images: `date -u "+%F %T"`"
