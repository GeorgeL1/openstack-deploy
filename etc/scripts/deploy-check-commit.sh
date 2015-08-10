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
# name: deploy-check-commit.sh
# Author: George Li
#
# Description
# - This script will use to deploy the target host as a Infrastructure Node
#

## Variables -----------------------------------------------------------------
REPO_URL=${REPO_URL:-"https://raw.githubusercontent.com/GeorgeL1/openstack-deployment/master"}
ANSIBLE_BRANCH=${ANSIBLE_BRANCH:-"juno"}
ANSIBLE_FOLDER=${ANSIBLE_FOLDER:-"/opt/os-ansible-deployment"}

# Infrastructure configuration
INF_HOST=${INF_HOST:-"infranode"}
COM_HOST=${COM_HOST:-"computenode"}
INF_IP=${INF_IP:-"192.168.88.200"}
COM_IP=${COM_IP:-"192.168.88.201"}

ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
DEPLOY_SWIFT=${DEPLOY_SWIFT:-"no"}

## Functions -----------------------------------------------------------------
source $(dirname ${0})/scripts-library.sh
info_block "Checking for required libraries."

## Main ----------------------------------------------------------------------

# ensure that the current kernel can support vxlan
if ! modprobe vxlan; then
  MINIMUM_KERNEL_VERSION=$(awk '/required_kernel/ {print $2}' rpc_deployment/inventory/group_vars/all.yml)
  info_block "A minimum kernel version of ${MINIMUM_KERNEL_VERSION} is required for vxlan support."
  exit 1
fi

# Get initial host information and reset verbosity
set +x && log_instance_info && set -x

# Copy the base etc files
if [ ! -d "/etc/rpc_deploy" ]; then
    cp -R ${ANSIBLE_FOLDER}/etc/rpc_deploy /etc

    USER_VARS_PATH="/etc/rpc_deploy/user_variables.yml"

    ## Adjust any defaults to suit the requirement.
    # commented lines are removed by pw-token-gen.py, so this substitution
    # need happen prior.
    sed -i "s/# nova_virt_type:.*/nova_virt_type: qemu/" ${USER_VARS_PATH}
    sed -i "s/# logstash_heap_size_mb:/logstash_heap_size_mb:/" ${USER_VARS_PATH}
    sed -i "s/# elasticsearch_heap_size_mb:/elasticsearch_heap_size_mb:/" ${USER_VARS_PATH}

    # Generate random passwords and tokens
    ${ANSIBLE_FOLDER}/scripts/pw-token-gen.py --file ${USER_VARS_PATH}

    # Reduce galera gcache size
    if grep -q galera_gcache_size ${USER_VARS_PATH}; then
        sed -i 's/galera_gcache_size:.*/galera_gcache_size: 50M/'
    else
        echo 'galera_gcache_size: 50M' >> ${USER_VARS_PATH}
    fi

    # reduce the mysql innodb_buffer_pool_size
    echo 'innodb_buffer_pool_size: 512M' | tee -a ${USER_VARS_PATH}

    # Set the minimum kernel version to our specific kernel release because it passed the vxlan test.
    echo "required_kernel: $(uname --kernel-release)" | tee -a ${USER_VARS_PATH}

    # change the generated passwords for the OpenStack (admin) and Kibana (kibana) accounts
    sed -i "s/keystone_auth_admin_password:.*/keystone_auth_admin_password: ${ADMIN_PASSWORD}/" ${USER_VARS_PATH}
    sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" ${USER_VARS_PATH}

    USER_CONFIG_PATH="/etc/rpc_deploy/rpc_user_config.yml"
    ENV_CONFIG_PATH="/etc/rpc_deploy/rpc_environment.yml"

    # download user configure file from repo.
    if [ -f ${USER_CONFIG_PATH} ]; then
        rm -f ${USER_CONFIG_PATH} 
    fi
    wget -O ${USER_CONFIG_PATH} $REPO_URL/etc/${ANSIBLE_BRANCH}/rpc_user_config.yml

    # adjust the default user configuration.
    sed -i "s/environment_version: .*/environment_version: $(md5sum ${ENV_CONFIG_PATH} | awk '{print $1}')/" ${USER_CONFIG_PATH}
    sed -i 's/INF_IP/'"$INF_IP"'/' ${USER_CONFIG_PATH}
    sed -i 's/INF_HOST/'"$INF_HOST"'/' ${USER_CONFIG_PATH}
    sed -i 's/COM_IP/'"$COM_IP"'/' ${USER_CONFIG_PATH}
    sed -i 's/COM_HOST/'"$COM_HOST"'/' ${USER_CONFIG_PATH}

    if [ -f "/etc/rpc_deploy/conf.d/swift.yml" ]; then
        rm -f /etc/rpc_deploy/conf.d/swift.yml
    fi
    wget -O /etc/rpc_deploy/conf.d/swift.yml $REPO_URL/etc/${ANSIBLE_BRANCH}/swift.yml
    sed -i 's/INF_IP/'"$INF_IP"'/' /etc/rpc_deploy/conf.d/swift.yml
    sed -i 's/INF_HOST/'"$INF_HOST"'/' /etc/rpc_deploy/conf.d/swift.yml

fi

info_block "The system has been prepared for deployment."

