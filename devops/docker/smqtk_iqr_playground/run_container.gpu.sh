#!/bin/bash
#
# Simple script for starting the SMQTK IQR container over a directory of
# images. The ``-t`` option may be optionally provided to tile input imagery
# into 128x128 tiles (default). We drop into watching the processing status
# after starting the container.
#
# If the container is already running, we just start watching the container's
# status.
#
set -e

CONTAINER_NAME="smqtk_iqr_gpu"
IQR_GUI_PORT_PUBLISH=5000
IQR_REST_PORT_PUBLISH=5001

# Replace SOMETHING_HERE by the real version (probably a date)
IMAGE_VERSION=`docker image ls | grep iqr | awk '{print $2}' | cut -d\- -f1`
if [ -z "$IMAGE_VERSION"]; then
    echo "Unable to determine image version from Docker. Exiting."
    exit 2
fi

GPU_SUFFIX=-gpu-cuda8-cudnn6

IQR_CONTAINER=kitware/smqtk/iqr_playground
IQR_CONTAINER_VERSION="${IMAGE_VERSION}${GPU_SUFFIX}"

if [ -z "$( docker ps -a | grep "${CONTAINER_NAME}" 2>/dev/null )" ]
then
  IMAGE_DIR="$1"
  # Make sure image directory exists as a directory.
  if [ ! -d "${IMAGE_DIR}" ]
  then
    echo "ERROR: Input image directory path was not a directory: ${IMAGE_DIR}"
    exit 1
  fi
  shift
  nvidia-docker run -d \
    -p ${IQR_GUI_PORT_PUBLISH}:5000 \
    -p ${IQR_REST_PORT_PUBLISH}:5001 \
    -v "${IMAGE_DIR}":/images \
    --name "${CONTAINER_NAME}" \
    ${IQR_CONTAINER}:${IQR_CONTAINER_VERSION} -b "$@"
fi

watch -n1 "
nvidia-smi
docker exec ${CONTAINER_NAME} bash -c '[ -d data/image_tiles ] && echo && echo \"Image tiles generated: \$(ls data/image_tiles | wc -l)\"'
echo
docker exec ${CONTAINER_NAME} tail \
    data/logs/compute_many_descriptors.log \
    data/logs/train_itq.log data/logs/compute_hash_codes.log \
    data/logs/runApp.IqrSearchDispatcher.log \
    data/logs/runApp.IqrService.log
"
