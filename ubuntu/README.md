# Ubuntu Kickstart installation

This repository contains script that will deploy Ubuntu 14.04 (Trusty Tahr) into a virtual
or physical machines. These scripts are based on the [Official Ubuntu Documentation]
(https://help.ubuntu.com/lts/installation-guide/i386/ch04s06.html).

Look through configure file for any changes you want to do.

You may want to change the initial admin user, or enable root user to login. current
user name is openstack and password is openStack2015, also you may want to change the
list of installed packages. tried to keep it as minimal as possible.

Place this somewhere that the machine will be able to see, Web server on LAN would be best.

People setting up in VMware the kernel has support for VMXNET3 compiled in so you can use
it for initial installation.

# Usage:
1. Boot up from ISO
2. Press F6 and hit escape so you an edit the boot line, add the following the end before the --.
for example if you did include the "--" the end of boot line would be:

	ks=http://your-server/openstack/ubuntu/ks-trusty.cfg --
	
3. That's it!, it will grab an IP via DHCP server on eth0 and setup the system.