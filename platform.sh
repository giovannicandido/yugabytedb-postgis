#!/bin/bash

TARGETARCH=$TARGETPLATFORM

if [ -z $TARGETARCH ]; then
  echo "Target Architecture is not detected"
  exit 1
fi

echo "Target Architecture: ${TARGETARCH}"
case $TARGETARCH in

  "linux/amd64")
	echo "x86_64" > /.platform
	;;
  "linux/arm64")
	echo "aarch64" > /.platform
	;;
esac