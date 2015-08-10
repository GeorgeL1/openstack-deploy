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
# name: setup-infra.sh
# Author: George Li
#
# Description
# - This script will use to deploy the target host as a Infrastructure Node
#

# check network connectivity, stop script if no internet access
if ! (curl --silent --head http://www.google.com/  | egrep "20[0-9] Found|30[0-9] Found" >/dev/null) then
    echo "Internet connection is required to run this script! "
    exit 1
fi

## Variables -----------------------------------------------------------------
export REPO_URL=${REPO_URL:-"https://raw.githubusercontent.com/GeorgeL1/openstack-deployment/master"}
export ANSIBLE_REPO=${ANSIBLE_REPO:-"https://github.com/stackforge/os-ansible-deployment"}
export ANSIBLE_BRANCH=${ANSIBLE_BRANCH:-"juno"}
export ANSIBLE_FOLDER=${ANSIBLE_FOLDER:-"/opt/os-ansible-deployment"}

# default password for OpenStack and kibana
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}

# Infrastructure configuration
export INF_HOST=${INF_HOST:-"infranode"}
export INF_IP=${INF_IP:-"192.168.0.200"}
export COM_HOST=${COM_HOST:-"computenode"}
export COM_IP=${COM_IP:-"192.168.0.201"}
export NET_MASK=${NET_MASK:-"255.255.255.0"}
export NET_GATE=${NET_GATE:-"192.168.0.1"}

export TARGET_HOST=${TARGET_HOST:-${INF_HOST}}
export TARGET_IP=${TARGET_IP:-${INF_IP}}

# Deployment options
export RUN_PLAYBOOKS=${RUN_PLAYBOOKS:-"yes"}
export DEPLOY_HOST=${DEPLOY_HOST:-"yes"}
export DEPLOY_LB=${DEPLOY_LB:-"yes"}
export DEPLOY_INFRASTRUCTURE=${DEPLOY_INFRASTRUCTURE:-"yes"}
export DEPLOY_OPENSTACK=${DEPLOY_OPENSTACK:-"yes"}

## Functions -----------------------------------------------------------------
source $(dirname ${0})/scripts/scripts-library.sh

## Main -----------------------------------------------------------------------

if [ -d "$(dirname ${0})/scripts" ]; then
    rm -rf $(dirname ${0})/scripts
fi

mkdir -p /etc/scripts
# Download the required scripts file into place
wget -O $(dirname ${0})/scripts/scripts-library.sh $REPO_URL/etc/scripts/scripts-library.sh
wget -O $(dirname ${0})/scripts/bootstrap-ansible.sh $REPO_URL/etc/scripts/bootstrap-ansible.sh
wget -O $(dirname ${0})/scripts/deploy-target-host.sh $REPO_URL/etc/scripts/deploy-target-host.sh
wget -O $(dirname ${0})/scripts/deploy-check-commit.sh $REPO_URL/etc/scripts/deploy-check-commit.sh
wget -O $(dirname ${0})/scripts/deploy-run-playbooks.sh $REPO_URL/etc/scripts/deploy-run-playbooks.sh

# Check if the ip address is meet requirement
if [ ! $(ip -o -4 addr show dev eth0 | awk -F '[ /]+' '/global/ {print $4}') = $TARGET_IP ]; then
	bash $(dirname ${0})/scripts/deploy-target-host.sh
	exit 1
fi

# Download the required interfaces configuration file into place
if [ ! -f "/etc/network/interfaces.d/openstack-infra.cfg" ]; then
    wget -O /etc/network/interfaces.d/openstack-infra.cfg $REPO_URL/etc/network/interfaces.d/openstack-infra.cfg
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

# check if the target hosts ip is reachable.
if ! ping -c 1 -W 1 $INF_IP >/dev/null; then
	info_block "the target host - $INF_IP is not reachable."
	exit 1
fi

if ! ping -c 1 -W 1 $COM_IP >/dev/null; then
	info_block "the target host - $COM_IP is not reachable."
	exit 1
fi

# Bootstrap ansible if required
if [ ! -d "${ANSIBLE_FOLDER}" ]; then
    bash $(dirname ${0})/scripts/bootstrap-ansible.sh
fi

# adjust rpc configure files
if [ ! -d "/etc/rpc_deploy" ]; then
    bash $(dirname ${0})/scripts/deploy-check-commit.sh
fi

# run playbooks
if [ "${RUN_PLAYBOOKS}" == "yes" ]; then
    bash $(dirname ${0})/scripts/deploy-run-playbooks.sh
fi

info_block "setup is complete,  please check the openstack link"