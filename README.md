# openstack-deployment

This repository is intend to deploy OpenStack environment in LXC containers using [openstack-ansible] (https://github.com/stackforge/os-ansible-deployment) in a two-node configuration with two NICs. One NIC is used for management, API and VM to VM traffice, the other NIC is for external network access.

This is just for testing with deploying OpenStack in container.

These scripts are based on the [Rackspace Private Cloud (RPC) v10 documentation]
(http://docs.rackspace.com/rpc/api/v10/bk-rpc-installation/content/rpc-common-front.html)
