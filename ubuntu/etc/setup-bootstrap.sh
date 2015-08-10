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
# name: setup-bootstrap.sh
# Author: George Li
#
# Description
# - This script is use to initialise the ubuntu environment and download
#   required script and configure files from repository.
# - This script will be execute when system booting up at first time.
#

## Shell Opts ---------------------------------
set -e -u -x

## Vars ---------------------------------------
REPO_URL="https://raw.githubusercontent.com/GeorgeL1/openstack-deployment/master"

# check network connectivity, stop script if no internet access
if ! (curl --silent --head http://www.google.com/  | egrep "20[0-9] Found|30[0-9] Found" >/dev/null) then
   echo "* Internet connection is required to run this script (setup-offline.sh)! "
   exit 0
fi

# Update the package cache.
apt-get update

# Upgrade all package but keep old configure file
apt-get -o Dpkg::Options::="--force-confold" -y dist-upgrade

# Install required packages
apt-get install -y tcptrack

# Remove unused Kernels
dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs apt-get -y purge

# Download the required script file into place
echo -n "Download the required configurate file into place ..."
wget -O /etc/issue $REPO_URL/ubuntu/etc/issue
wget -O /etc/issue.net $REPO_URL/ubuntu/etc/issue.net
wget -O /etc/motd.footer $REPO_URL/ubuntu/etc/motd.footer
wget -O /etc/motd.tail $REPO_URL/ubuntu/etc/motd.tail
wget -O /etc/ramdisk.sh $REPO_URL/ubuntu/etc/ramdisk.sh
echo .

# Enable banner in sshd_config
if grep "^#Banner" /etc/ssh/sshd_config > /dev/null; then
  sed -i 's/^#Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
else
  echo 'Banner /etc/issue.net' >> /etc/ssh/sshd_config
fi

# Ensure that sshd permits root login.
if grep "^PermitRootLogin" /etc/ssh/sshd_config > /dev/null; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi

# Enable Welcome info for remote console - 00-header
if [ -f /etc/update-motd.d/00-header ]; then
   if ! grep "motd.tail" /etc/update-motd.d/00-header > /dev/null; then
      sed -i 's/printf "Welcome/if [ -f \/etc\/motd.tail ]; then\n cat \/etc\/motd.tail\nfi\n\n&/g' /etc/update-motd.d/00-header
   fi
else
   (
cat << 'EOF'
#!/bin/sh
#
#    00-header - create the header of the MOTD
#    Copyright (C) 2009-2010 Canonical Ltd.
#
#    To add dynamic information, add a numbered
#    script to /etc/update-motd.d/

[ -f /etc/motd.tail ] && cat /etc/motd.tail || true

printf "Welcome to %s (%s %s %s)\n" "$DISTRIB_DESCRIPTION" "$(uname -o)" "$(uname -r)" "$(uname -m)"
EOF
    ) > /etc/update-motd.d/00-header
fi

# Enable Welcome info for remote console - 99-info-text
if [ -f /etc/update-motd.d/99-info-text ]; then
   if ! grep "motd.footer" /etc/update-motd.d/99-info-text > /dev/null; then
      echo '[ -f /etc/motd.footer ] && cat /etc/motd.footer || true' >> /etc/update-motd.d/99-info-text
   fi
else
    (
cat << 'EOF'
#!/bin/sh
#
#    99-footer - write the admin's footer to the MOTD
#    Copyright (C) 2009-2010 Canonical Ltd.
#
#    To add dynamic information, add a numbered
#    script to /etc/update-motd.d/

[ -f /etc/motd.footer ] && cat /etc/motd.footer || true
EOF
    ) > /etc/update-motd.d/99-info-text
fi

# Enable Login Welcome messages
chmod +x /etc/update-motd.d/00-header
chmod +x /etc/update-motd.d/99-info-text

# Disable update and upgrade messages
chmod -x /etc/update-motd.d/10-help-text
chmod -x /etc/update-motd.d/90-updates-available
chmod -x /etc/update-motd.d/91-release-upgrade

# image clean up .
apt-get autoremove -y
apt-get clean
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/*cache.bin
rm -f /var/lib/apt/lists/*_Packages
rm -rf /usr/src/*

# Setup completed, so disable the setup-bootstrap.sh
chmod -x /etc/setup-bootstrap.sh
sed -i '/setup-bootstrap.sh/d' /etc/rc.local

reboot
