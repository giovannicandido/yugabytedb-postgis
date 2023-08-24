#!/usr/bin/env bash
set -eu -o pipefail

function docker_tag_exists() {
  curl --silent -f -lSL -H "Authorization: Bearer $GITHUB_TOKEN" https://ghcr.io/v2/$1/manifests/$2 > /dev/null
}

echo "Checking if image https://ghcr.io/v2/$1/manifests/$2 exists"

if docker_tag_exists $1 $2; then
  echo "Image exits"
  exit 0
else
  echo "Image not exists proceeding with build"
fi