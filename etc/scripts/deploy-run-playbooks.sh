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
# name: deploy-run-playbooks.sh
# Author: George Li
#
# Description
# - This script will use to deploy the target host as a Infrastructure Node
#

## Shell Opts ----------------------------------------------------------------
set -e -u -v +x

## Variables -----------------------------------------------------------------
ANSIBLE_BRANCH=${ANSIBLE_BRANCH:-"juno"}
ANSIBLE_FOLDER=${ANSIBLE_FOLDER:-"/opt/os-ansible-deployment"}

DEPLOY_HOST=${DEPLOY_HOST:-"yes"}
DEPLOY_LB=${DEPLOY_LB:-"yes"}
DEPLOY_INFRASTRUCTURE=${DEPLOY_INFRASTRUCTURE:-"yes"}
DEPLOY_OPENSTACK=${DEPLOY_OPENSTACK:-"yes"}
DEPLOY_LOGGING=${DEPLOY_LOGGING:-"yes"}
DEPLOY_SWIFT=${DEPLOY_SWIFT:-"no"}
DEPLOY_RPC_SUPPORT=${DEPLOY_RPC_SUPPORT:-"yes"}
DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}

## Functions -----------------------------------------------------------------
source $(dirname ${0})/scripts-library.sh
info_block "Checking for required libraries."

## Main ----------------------------------------------------------------------

cd ${ANSIBLE_FOLDER}

pushd "rpc_deployment"

    if [ "${DEPLOY_HOST}" == "yes" ]; then
        # Install all host bits
        install_bits setup/host-setup.yml
    fi

    if [ "${DEPLOY_LB}" == "yes" ]; then
        # Install haproxy for dev purposes only
        install_bits infrastructure/haproxy-install.yml
    fi

    if [ "${DEPLOY_INFRASTRUCTURE}" == "yes" ]; then
        # Install all of the infra bits
        install_bits infrastructure/infrastructure-setup.yml
    fi

    if [ "${DEPLOY_OPENSTACK}" == "yes" ]; then
        # install all of the OpenStack Bits
        install_bits openstack/openstack-setup.yml
    fi

popd