#!/bin/sh
## one script to be used by travis, jenkins, packer...

umask 022

rolesdir=$(dirname $0)/..

[ ! -d $rolesdir/juju4.snmpd ] && git clone https://github.com/juju4/ansible-snmpd $rolesdir/juju4.snmpd
[ ! -d $rolesdir/juju4.nrpeclient ] && git clone https://github.com/juju4/ansible-nrpeclient $rolesdir/juju4.nrpeclient
## galaxy naming: kitchen fails to transfer symlink folder
#[ ! -e $rolesdir/juju4.monclient ] && ln -s ansible-monclient $rolesdir/juju4.monclient
[ ! -e $rolesdir/juju4.monclient ] && cp -R $rolesdir/ansible-monclient $rolesdir/juju4.monclient

## don't stop build on this script return code
true

