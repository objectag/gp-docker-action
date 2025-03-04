#!/bin/sh

DOCKER_TOKEN=$1
DOCKER_IMAGE_NAME=$2
DOCKER_IMAGE_TAG=$3
EXTRACT_TAG_FROM_GIT_REF=$4
DOCKERFILE=$5
BUILD_CONTEXT=$6
PULL_IMAGE=$7
DOCKER_IMAGE_TAGS=$8
DOCKER_IMAGE_PLATFORM=$9
CUSTOM_DOCKER_BUILD_ARGS=${10}

if [ $EXTRACT_TAG_FROM_GIT_REF == "true" ]; then
  DOCKER_IMAGE_TAG=$(echo ${GITHUB_REF} | sed -e "s/refs\/tags\///g")
fi

DOCKER_IMAGE_NAME=$(echo ghcr.io/${GITHUB_REPOSITORY}/${DOCKER_IMAGE_NAME} | tr '[:upper:]' '[:lower:]')
DOCKER_IMAGE_NAME_WITH_TAG=$(echo ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} | tr '[:upper:]' '[:lower:]')

docker buildx create --use # Creating builder instance to support cross-platform builds

docker login -u publisher -p ${DOCKER_TOKEN} ghcr.io

if [ $PULL_IMAGE == "true" ]; then
  if [ $DOCKER_IMAGE_PLATFORM != "" ]; then
    docker pull $DOCKER_IMAGE_NAME_WITH_TAG --platform $DOCKER_IMAGE_PLATFORM || docker pull $DOCKER_IMAGE_NAME --platform $DOCKER_IMAGE_PLATFORM || true
  else
    docker pull $DOCKER_IMAGE_NAME_WITH_TAG || docker pull $DOCKER_IMAGE_NAME || true
  fi
fi

set -- -t $DOCKER_IMAGE_NAME_WITH_TAG

if [ $DOCKERFILE != "Dockerfile" ]; then
  set -- "$@" -f $DOCKERFILE
fi

if [ $DOCKER_IMAGE_PLATFORM != "" ]; then
  set -- "$@" --platform $DOCKER_IMAGE_PLATFORM
fi

if [ $CUSTOM_DOCKER_BUILD_ARGS != "" ]; then
  set -- "$@" $CUSTOM_DOCKER_BUILD_ARGS
fi

set -- "$@" $BUILD_CONTEXT

for tag in $DOCKER_IMAGE_TAGS
do
    DOCKER_IMAGE_NAME_WITH_TAG=$(echo ${DOCKER_IMAGE_NAME}:${tag} | tr '[:upper:]' '[:lower:]')
    set -- -t $DOCKER_IMAGE_NAME_WITH_TAG "$@"
done

echo "$@"

docker buildx build --push "$@"
