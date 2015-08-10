#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# name: ramdisk.sh
# Author: George Li
#
# Description
# - This script will be use to mount specific folder into RAM
#   for accelerating access speed,  also backup / restore 
#   the folder files between Disk and RAM when booting up
#

DISK=/xxx/xxx
DESC="Use RAM Disk to improve Disk Access"
DEFAULT=/etc
BACKUP=/opt/ramdisk
LOG=/var/log/ramdisk-sync.log
TODAY=`date +"%Y%m%d"`

# Exit if the DISK is not mounted
if [ $(cat /etc/fstab | grep -Fc "tmpfs   ${DISK}") != 1 ]; then
  echo " * ${DISK} is not mounted!";
  exit 0;
fi

if [ ! -d ${BACKUP} ] || [ ! -d ${DISK} ]; then
  echo " * ${BACKUP} is not exist, please create it manually!";
  exit 0;
fi

case "$1" in
  start)
    echo " * Restore $DISK to RAM ..."

    if [ -f ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ]; then
      # restore from $BACKUP folder if file exist
      tar -zxvf ${BACKUP}/ramdisk-${DISK##*/}.tar.gz --directory ${DISK%/*} > /dev/null;
      echo " * $DISK has be restore to RAM ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be restore to RAM! >> ${LOG}
      fi

    elif [ -f $[DEFAULT]/ramdisk-${DISK##*/}.tar.gz ]; then
      # restore from $DEFAULT folder if file exist
      tar -zxvf $[DEFAULT]/ramdisk-${DISK##*/}.tar.gz --directory ${DISK%/*} > /dev/null;
      echo " * $DISK has be restore to RAM ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be restore to RAM! >> ${LOG}
      fi

    else
      echo " * $DISK has NOT be restore to RAM due to missing backup file ...";
    fi
    ;;
  sync)
    echo " * Synchronize $DISK from RAM to Disk ..."

    if [ -f ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ]; then
      # rename existing file.
      mv -f ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ${BACKUP}/ramdisk-${DISK##*/}_${TODAY}.tar.gz;

      # backup $DISK RAM to Disk
      cd ${DISK%/*};
      tar -cvpzf ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ${DISK##*/} > /dev/null;
      echo " * $DISK has be synchronize to Disk ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be sychronize to Disk! >> ${LOG}
      fi

    elif [ -d ${BACKUP} ]; then
      # backup $DISK RAM to Disk
      cd ${DISK%/*};
      tar -cvpzf ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ${DISK##*/} > /dev/null;
      echo " * $DISK has be synchronize to Disk ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be sychronize to Disk! >> ${LOG}
      fi

    else
      echo " * $DISK has NOT be synchronize to RAM due to invalid backup folder ...";
    fi
    ;;
  stop)
    echo " * Backup $DISK to Disk ..."

    if [ -f ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ]; then
      # delete existing file.
      rm -f ${BACKUP}/ramdisk-${DISK##*/}.tar.gz;

      # backup $DISK RAM to Disk
      cd ${DISK%/*};
      tar -cvpzf ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ${DISK##*/} > /dev/null;
      echo " * $DISK has be synchronize to Disk ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be backup to Disk! >> ${LOG}
      fi

    elif [ -d ${BACKUP} ]; then
      # backup $DISK RAM to Disk
      cd ${DISK%/*};
      tar -cvpzf ${BACKUP}/ramdisk-${DISK##*/}.tar.gz ${DISK##*/} > /dev/null;
      echo " * $DISK has be synchronize to Disk ...";

      # write to log file
      if [ -f ${LOG} ]; then
        echo [`date +"%Y-%m-%d %H:%M"`] $DISK has be backup to Disk! >> ${LOG}
      fi

    else
      echo " * $DISK has NOT be backup to Disk due to invalid backup folder ...";
    fi
    ;;
  *)
    echo "Usage: /etc/init.d/ramdisk-${DISK##*/} {start|stop|sync}"
    exit 1
    ;;
esac

exit 0