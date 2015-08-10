#!/usr/bin/env bash
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
# name: deploy-target-host.sh
# Author: George Li
#
# Description
# - This script will use to install the require the package and configure 
#   network interface for target host
#

## Variables -----------------------------------------------------------------

TARGET_HOST=${TARGET_HOST:-"targetnode"}
TARGET_IP=${TARGET_IP:-"192.168.0.200"}
NET_MASK=${NET_MASK:-"255.255.255.0"}
NET_GATE=${NET_GATE:-"192.168.0.1"}

## Functions -----------------------------------------------------------------
source $(dirname ${0})/scripts-library.sh

## Main -----------------------------------------------------------------------
info_block "Network configuration for Target host"

# Update the package cache.
apt-get update

# Upgrade all package but keep old configure file
apt-get -o Dpkg::Options::="--force-confold" -y upgrade

# Install required packages
apt-get install -y aptitude \
                   build-essential \
                   git \
                   ntp \
                   ntpdate \
                   openssh-server \
                   python-dev \
                   sudo \
                   bridge-utils \
                   debootstrap \
                   ifenslave \
                   lsof \
                   lvm2 \
                   tcpdump \
                   vlan

# Set hostname
echo "$TARGET_HOST.localdomain" > /etc/hostname

# Set Infrastructure hosts
if grep $TARGET_HOST /etc/hosts > /dev/null; then
    sed -i '/'"$TARGET_HOST"'/d' /etc/hosts
fi
echo "127.0.0.1 $TARGET_HOST   $TARGET_HOST.localdomain" >> /etc/hosts

# Set up new IP address in interfaces configuration file
if [ -f "/etc/network/interfaces" ]; then
    mv /etc/network/interfaces /etc/network/interfaces.bak
fi

cat > /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
    address $TARGET_IP
    netmask $NET_MASK
    gateway $NET_GATE
    dns-nameservers 8.8.8.8 8.8.4.4

auto eth1
iface eth1 inet manual

EOF

# server need to reboot for new IP address.
echo "* please check the network interface configuration, reboot this server and run the script again..."
