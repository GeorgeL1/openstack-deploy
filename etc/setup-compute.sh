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
# name: setup-compute.sh
# Author: George Li
#
# Description
# - This script will use to deploy the target host as a Compute Node
#

# check network connectivity, stop script if no internet access
if ! (curl --silent --head http://www.google.com/  | egrep "20[0-9] Found|30[0-9] Found" >/dev/null) then
    echo "Internet connection is required to run this script! "
    exit 1
fi

## Variables -----------------------------------------------------------------
export REPO_URL=${REPO_URL:-"https://raw.githubusercontent.com/GeorgeL1/openstack-deployment/master"}

# Infrastructure configuration
export COM_HOST=${COM_HOST:-"computenode"}
export COM_IP=${COM_IP:-"192.168.0.201"}
export NET_MASK=${NET_MASK:-"255.255.255.0"}
export NET_GATE=${NET_GATE:-"192.168.0.1"}

export TARGET_HOST=${TARGET_HOST:-${COM_HOST}}
export TARGET_IP=${TARGET_IP:-${COM_IP}}

## Main -----------------------------------------------------------------------

if [ -d "$(dirname ${0})/scripts" ]; then
    rm -rf $(dirname ${0})/scripts
fi

mkdir -p $(dirname ${0})/scripts
# Download the required scripts file into place
wget -O $(dirname ${0})/scripts/scripts-library.sh $REPO_URL/etc/scripts/scripts-library.sh
wget -O $(dirname ${0})/scripts/deploy-target-host.sh $REPO_URL/etc/scripts/deploy-target-host.sh

# Check if the ip address is meet requirement
if [ ! $(ip -o -4 addr show dev eth0 | awk -F '[ /]+' '/global/ {print $4}') = $TARGET_IP ]; then
  bash $(dirname ${0})/scripts/deploy-target-host.sh
  exit 1
fi

# Download the required interfaces configuration file into place
if [ ! -f "/etc/network/interfaces.d/openstack-compute.cfg" ]; then
    wget -O /etc/network/interfaces.d/openstack-compute.cfg $REPO_URL/etc/network/interfaces.d/openstack-compute.cfg
fi

# Ensure the network source is in place
if ! grep -q "^source /etc/network/interfaces.d/\*.cfg$" /etc/network/interfaces; then
    echo -e "\nsource /etc/network/interfaces.d/*.cfg" | tee -a /etc/network/interfaces
fi

# Bring up the new interfaces
for iface in $(awk '/^iface/ {print $2}' /etc/network/interfaces.d/*.cfg ); do
    if ! ip addr show $iface | grep 'state UP' > /dev/null; then
        /sbin/ifup $iface || true
    fi
done

echo "* Compute Node is ready, please configure and deploy the openstack from Infrastructure Node..."
