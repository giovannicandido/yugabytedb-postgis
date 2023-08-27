#!/usr/bin/env bash

TARGET_PLATFORM=`cat /.platform`

echo "Will install postgis in platform $TARGET_PLATFORM"

PLATFORM=$TARGET_PLATFORM

if [ -z $PLATFORM ]; then
  echo "Error platform is not detected"
  exit 1
fi

yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-${PLATFORM}/pgdg-redhat-repo-latest.noarch.rpm

dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools
dnf -qy module disable postgresql

yum install -y postgresql11-server postgis33_11 postgis33_11-client

if [ $PLATFORM = 'aarch64' ]; then
  curl -O http://linuxsoft.cern.ch/centos-altarch/7/updates/$PLATFORM/Packages/libxml2-2.9.1-6.el7_9.6.$PLATFORM.rpm
else 
  curl -O http://mirror.centos.org/centos/7/updates/$PLATFORM/Packages/libxml2-2.9.1-6.el7_9.6.$PLATFORM.rpm
fi

rpm2cpio libxml2-2.9.1-6.el7_9.6.$PLATFORM.rpm | cpio -idmv
rm -f lib/yb-thirdparty/libxml2.so.2
cp usr/lib64/libxml2.so.2* lib/yb-thirdparty/
rm -rf usr

cp -v "$(/usr/pgsql-11/bin/pg_config --pkglibdir)"/*postgis*.so "$(postgres/bin/pg_config --pkglibdir)" &&
cp -v "$(/usr/pgsql-11/bin/pg_config --sharedir)"/extension/*postgis*.sql "$(postgres/bin/pg_config --sharedir)"/extension &&
cp -v "$(/usr/pgsql-11/bin/pg_config --sharedir)"/extension/*postgis*.control "$(postgres/bin/pg_config --sharedir)"/extension
bin/post_install.sh -e

yum autoremove -y postgresql11-server postgis33_11 postgis33_11-client

yum clean all
rm -rf /var/cache/yum

if [ $PLATFORM = 'aarch64' ]; then
  yum install -y geos-devel libtiff
  curl -O http://linuxsoft.cern.ch/centos-altarch/7/os/$PLATFORM/Packages/sqlite-3.7.17-8.el7_7.1.$PLATFORM.rpm
else
  curl -O https://rpmfind.net/linux/centos/7.9.2009/os/$PLATFORM/Packages/sqlite-3.7.17-8.el7_7.1.$PLATFORM.rpm
fi

rpm2cpio sqlite-3.7.17-8.el7_7.1.$PLATFORM.rpm | cpio -idmv

ls /

cp /lib64/libsqlite3.so.0.8.6 /libsqlite3.so.0.8.6.bak
cp /lib64/libsqlite3.so.0 /libsqlite3.so.0.bak

rm -rf /lib64/libsqlite3.so.0.8.6
rm -rf /lib64/libsqlite3.so.0
cp --remove-destination usr/lib64/libsqlite3.so.0 /lib64/
cp --remove-destination usr/lib64/libsqlite3.so.0.8.6 /lib64/
cp --remove-destination usr/lib64/libsqlite3.so.0.8.6 lib/yb-thirdparty/
cp --remove-destination usr/lib64/libsqlite3.so.0 lib/yb-thirdparty/
rm -rf usr/