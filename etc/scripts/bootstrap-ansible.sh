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
# name: bootstrap-ansible.sh
#

## Shell Opts ----------------------------------------------------------------
set -e -u -x

## Variables -----------------------------------------------------------------
REPO_URL=${REPO_URL:-"https://raw.githubusercontent.com/GeorgeL1/openstack-deployment/master"}
ANSIBLE_REPO=${ANSIBLE_REPO:-"https://github.com/stackforge/os-ansible-deployment"}
ANSIBLE_BRANCH=${ANSIBLE_BRANCH:-"juno"}
ANSIBLE_FOLDER=${ANSIBLE_FOLDER:-"/opt/os-ansible-deployment"}

INF_IP=${INF_IP:-"192.168.88.200"}
COM_IP=${COM_IP:-"192.168.88.201"}

## Functions -----------------------------------------------------------------
source $(dirname ${0})/scripts-library.sh

## Main ----------------------------------------------------------------------

# Get initial host information and reset verbosity
set +x && log_instance_info && set -x

info_block "Bootstrapping System with Ansible"

# Create the ssh dir if needed
ssh_key_create

# dispatch ssh key pair
ssh-copy-id root@$INF_IP
ssh-copy-id root@$COM_IP

# If the working directory exists remove it
if [ -d "${ANSIBLE_FOLDER}" ];then
    rm -rf "${ANSIBLE_FOLDER}"
fi

# Clone down the base os-ansible-deployment source
git clone "${ANSIBLE_REPO}" "${ANSIBLE_FOLDER}"
pushd "${ANSIBLE_FOLDER}"
	git checkout "${ANSIBLE_BRANCH}"
	git submodule update --init --recursive
popd

# Install pip
if [ ! -f "/opt/get-pip.py" ]; then
	curl https://bootstrap.pypa.io/get-pip.py > /opt/get-pip.py
    python /opt/get-pip.py --find-links="https://mirror.rackspace.com/rackspaceprivatecloud/python_packages/${ANSIBLE_BRANCH}" --no-index
fi

# Install requirements if exists
if [ -f "${ANSIBLE_FOLDER}/requirements.txt" ]; then
    pip install -r ${ANSIBLE_FOLDER}/requirements.txt
fi

echo "System is bootstrap and ready to use."




