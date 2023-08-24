#!/usr/bin/env bash
set -eu -o pipefail

IMAGES=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

usage() {
  echo "$0 usage: <arguments> -farm <URI for package tarball> -fx86 <URI for package tarball>  <-- docker build opts>"
  echo "  -x <Package URI>  URI to package tarball X86.  Supports https, s3, scp, and local files"
  echo "  -a <Package URI>  URI to package tarball ARM.  Supports https, s3, scp, and local files"
  echo "  -r <repository>   Docker hub repository.  Default is 'ghcr.io/giovannicandido'"
  echo "  -l                Tag the image as tag_latest"
  echo "Anything after -- is passed to the docker build command"
}
[ $# -eq 0 ] && usage && exit 1

uri=''
uriarm=''
urix86=''
repo_name='ghcr.io/giovannicandido'
tag_latest=false
tag_arch=false
while getopts ":h:x:a:r:l" arg; do
  case $arg in
    a) # URI for the yugabyte arm tarball to dockerize
      uriarm=${OPTARG}
      ;;
    x) # URI for yugabyte tarbal x86 to dockerize
      urix86=${OPTARG}
      ;;
    r) # Docker repo to prefix with which to prefix the image name
      repo_name=${OPTARG}
      ;;
    l) # Enable latest tagging
      tag_latest=true
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done
# Eat our args so we can pass the rest to docker build command
shift $((OPTIND - 1))

# Detect if we are passing a UBI base image and give some advice if so
# BASE_IMAGE=registry.access.redhat.com/ubi
if [[ "$@" == *"BASE_IMAGE=registry.access.redhat.com/ubi"* ]]; then
  if [[ "$@" != *"USER="* ]]; then
    echo "It is recommended that '--build-arg USER=yugabyte' be used in conjunction with a UBI \
      base image"
    echo "Hit <ctrl-c> now to exit and add the parameter or wait 5 seconds to continue"
    sleep 5
    echo "Proceeding"
  fi
fi

# Infer the workspace from the package name
tarball=$(basename $urix86)

#yugabyte-2.18.1.0-b68-almalinux8-aarch64.tar.gz
regex="(.*[^-])-([0-9]+([.][0-9]+){3}-[^-]+)-(.*[^-])-(.*[^.]).tar"
target=yugabytedb-postgis
if [[ $tarball =~ $regex ]]; then
  full_version="${BASH_REMATCH[2]}"
  os="${BASH_REMATCH[4]}"
  package_prefix="${BASH_REMATCH[1]}"-"${BASH_REMATCH[2]}"-"${BASH_REMATCH[4]}"
else
  echo "Can't parse $tarball"
  exit 1
fi


# Determine out arch from the passed in package name
docker_arch_arg="--platform linux/amd64,linux/arm64"


# Try to parse some version info
version=${full_version%-*}
build_number=$(tr -d b <<<${full_version#*-})

if [[ ! -d $IMAGES/$target ]]; then
  echo "Docker workspace for ${target} doesn't exist for package"
  usage
  exit 1
fi

pkg_dir="$IMAGES/$target/packages"
# This is where we'll copy the URI to
if [[ -d $pkg_dir ]]; then
  echo "Packages directory already exists, deleting"
  echo
  rm -rf $pkg_dir
fi

mkdir -p $pkg_dir
trap "rm -rf $pkg_dir" EXIT

echo "Creating multi arch docker image for $target $full_version"
echo "The image will be called ${repo_name}/${target}:${full_version}"
echo

case $uriarm in
  http*) # Grab the file from a URL
    curl -L -s --output-dir $pkg_dir -O $uriarm
    ;;
  s3*) # Grab the file from s3
    aws s3 cp --only-show-errors $uriarm $pkg_dir/
    ;;
  *@*) # Lets try scp
    scp $uriarm $pkg_dir/
    ;;
  *) # This should be a local file, or at least "local"
    cp $uriarm $pkg_dir/
esac

case $urix86 in
  http*) # Grab the file from a URL
    curl -L -s --output-dir $pkg_dir -O $urix86
    ;;
  s3*) # Grab the file from s3
    aws s3 cp --only-show-errors $urix86 $pkg_dir/
    ;;
  *@*) # Lets try scp
    scp $urix86 $pkg_dir/
    ;;
  *) # This should be a local file, or at least "local"
    cp $urix86 $pkg_dir/
esac

# Time to build the image
(set -x;
docker buildx build \
  --build-arg VERSION=$version \
  --build-arg RELEASE=$build_number \
  --build-arg PACKAGE_NAME_PREFIX=$package_prefix \
  --tag $repo_name/$target:$full_version \
  --push \
  $docker_arch_arg \
  $@ $IMAGES/$target)
if $tag_latest; then
  (set -x; docker tag $repo_name/$target:$full_version $repo_name/$target:latest)
fi
