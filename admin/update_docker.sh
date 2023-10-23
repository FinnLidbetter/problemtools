#!/bin/bash
set -e

KOTLIN_VERSION=1.7.21

TAG=develop
UPDATE_LATEST=false
if [ "$1" != "" ]; then
    TAG=$1
    UPDATE_LATEST=true
fi


cd $(dirname $(readlink -f $0))/docker
set -x

# Make the build image and extract build artifacts
# ===============================================
docker buildx build \
     -f Dockerfile.build \
     -t finnlidbetter/problemtools-arm-build:${TAG} \
     --no-cache \
     --build-arg PROBLEMTOOLS_VERSION="${TAG}" \
     .
mkdir -p artifacts
rm -rf artifacts/deb/*
docker run --rm -v "$(pwd)/artifacts/:/artifacts" finnlidbetter/problemtools-arm-build:${TAG} cp -r /usr/local/problemtools_build/deb /artifacts
sudo chown -R $(id -u $USER):$(id -g $USER) artifacts/

# Get Kotlin since it is not available through apt
# ===============================================
mkdir -p artifacts/kotlin
curl -L -o artifacts/kotlin/kotlinc.zip https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip


# Build the actual problemtools images
# ===============================================
for IMAGE in minimal icpc full; do
    docker buildx build\
         -f Dockerfile.${IMAGE}\
         -t finnlidbetter/problemtools-arm-${IMAGE}:${TAG}\
         --build-arg PROBLEMTOOLS_VERSION=${TAG}\
         .
    if [ "$UPDATE_LATEST" = "true" ]; then
        docker tag finnlidbetter/problemtools-arm-${IMAGE}:${TAG} finnlidbetter/problemtools-arm-${IMAGE}:latest
    fi
done


# Push to Docker Hub
# ===============================================
docker login
for IMAGE in minimal icpc full; do
    docker push finnlidbetter/problemtools-arm-${IMAGE}:${TAG}
    if [ "$UPDATE_LATEST" = "true" ]; then
        docker push finnlidbetter/problemtools-arm-${IMAGE}:latest
    fi
done
