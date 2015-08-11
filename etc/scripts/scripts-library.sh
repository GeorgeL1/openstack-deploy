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
# refer to script in os-ansible-deployment git

## Variables -----------------------------------------------------------------

LINE='-----------------------------------------------------------------------'
MAX_RETRIES=${MAX_RETRIES:-5}
REPORT_DATA=${REPORT_DATA:-""}
STARTTIME="${STARTTIME:-$(date +%s)}"
ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-"-e @/etc/rpc_deploy/user_variables.yml"}

# the number of forks is set as the number of CPU's present 
FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}

# Override the current HOME directory
export HOME="/root"

## Functions ------------------------------------------------------------------

# Output details provided as parameters
function print_info() {
    set +x
    PROC_NAME="- [ $@ ] -"
    printf "\n%s%s\n" "$PROC_NAME" "${LINE:${#PROC_NAME}}"
}

# Output a formatted block around a message
function info_block(){
    set +x
    echo "${LINE}"
    print_info "$@"
    echo "${LINE}"
}

function ssh_key_create(){
    # Ensure that the ssh key exists and is an authorized_key
    key_path="${HOME}/.ssh"
    key_file="${key_path}/id_rsa"

    # Ensure that the .ssh directory exists and has the right mode
    if [ ! -d ${key_path} ]; then
        mkdir -p ${key_path}
        chmod 700 ${key_path}
    fi

    if [ ! -f "${key_file}" ] || [ ! -f "${key_file}.pub" ]; then
        rm -f ${key_file}*
        ssh-keygen -t rsa -f ${key_file} -N ''
    fi

    # Ensure that the public key is included in the authorized_keys
    # for the default root directory and the current home directory
    key_content=$(cat "${key_file}.pub")
    if ! grep -q "${key_content}" ${key_path}/authorized_keys; then
        echo "${key_content}" | tee -a ${key_path}/authorized_keys
    fi
}

# Exit with error details
function exit_fail() {
    set +x
    log_instance_info
    info_block "Error Info - $@"
    exit_state 1
}

function log_instance_info() {
    set +x
    # Get host information post initial setup and reset verbosity
    if [ ! -d "/openstack/log/instance-info" ];then
        mkdir -p "/openstack/log/instance-info"
    fi
    get_instance_info &> /openstack/log/instance-info/host_info_$(date +%s).log
    set -x
}

# Output diagnostic information
function get_instance_info() {
    set +x
    info_block 'Path'
    echo ${PATH}
    info_block 'Current User'
    whoami
    info_block 'Home Directory'
    echo ${HOME}
    info_block 'Available Memory'
    free -mt
    info_block 'Available Disk Space'
    df -h
    info_block 'Mounted Devices'
    mount
    info_block 'Block Devices'
    lsblk -i
    info_block 'Block Devices Information'
    blkid
    info_block 'Block Device Partitions'
    for blk_dev in $(lsblk -nrdo NAME,TYPE | awk '/disk/ {print $1}'); do
        # Ignoring errors for the below command is important as sometimes
        # the block device in question is unpartitioned or has an invalid
        # partition. In this case, parted returns 'unrecognised disk label'
        # and the bash script exits due to the -e environment setting.
        parted --script /dev/$blk_dev print || true
    done
    info_block 'PV Information'
    pvs
    info_block 'VG Information'
    vgs
    info_block 'LV Information'
    lvs
    info_block 'Contents of /etc/fstab'
    cat /etc/fstab
    info_block 'CPU Information'
    which lscpu && lscpu
    info_block 'Kernel Information'
    uname -a
    info_block 'Container Information'
    which lxc-ls && lxc-ls --fancy
    info_block 'Firewall Information'
    iptables -vnL
    iptables -t nat -vnL
    iptables -t mangle -vnL
    info_block 'Network Devices'
    ip a
    info_block 'Network Routes'
    ip r
    info_block 'Trace Path from google'
    tracepath 8.8.8.8 -m 5
    dpkg-query --list &> /openstack/log/instance-info/host_packages_info_$(date +%s).log
    pip freeze &> /openstack/log/instance-info/pip_packages_info_$(date +%s).log
}

# Output a formatted block of information about the run on exit
function exit_state() {
    set +x
    info_block "Run time reports"
    echo -e "${REPORT_DATA}"
    TOTALSECONDS="$[$(date +%s) - $STARTTIME]"
    info_block "Run Time = ${TOTALSECONDS} seconds || $(($TOTALSECONDS / 60)) minutes"
    if [ "${1}" == 0 ];then
        info_block "Status: Build Success"
    else
        info_block "Status: Build Failure"
    fi
    exit ${1}
}

# Used to retry a process that may fail due to transient issues
function successerator() {
    set +e
    # Get the time that the method was started.
    OP_START_TIME="$(date +%s)"
    RETRY=0
    # Set the initial return value to failure.
    false
    while [ $? -ne 0 -a ${RETRY} -lt ${MAX_RETRIES} ];do
        RETRY=$((${RETRY}+1))
        if [ ${RETRY} -gt 1 ];then
            $@ -vvvv
        else
            $@
        fi
    done
    # If max retires were hit, fail.
    if [ $? -ne 0 ] && [ ${RETRY} -eq ${MAX_RETRIES} ];then
        echo -e "\nHit maximum number of retries, giving up...\n"
        exit_fail
    fi
    # Print the time that the method completed.
    OP_TOTAL_SECONDS="$[$(date +%s) - $OP_START_TIME]"
    REPORT_OUTPUT="${OP_TOTAL_SECONDS} seconds"
    REPORT_DATA+="- Operation: [ $@ ]\t${REPORT_OUTPUT}\tNumber of Attempts [ ${RETRY} ]\n"
    echo -e "Run Time = ${REPORT_OUTPUT}"
    set -e
}

function install_bits() {
    # The number of forks has been limited to 5 by default
    # This will also run ansible in 3x verbose mode
    successerator ansible-playbook ${ANSIBLE_PARAMETERS} --forks ${FORKS} playbooks/$@
}

# Exit if the script is not being run as root
if [ ! "$(whoami)" == "root" ]; then
    info_block "This script must be run as root."
    exit 1
fi

# Trap all Death Signals and Errors
trap "exit_fail ${LINENO} $? 'Received STOP Signal'" SIGHUP SIGINT SIGTERM
trap "exit_fail ${LINENO} $?" ERR
