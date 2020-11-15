[![Build Status - Master](https://travis-ci.com/juju4/ansible-monclient.svg?branch=master)](https://travis-ci.com/juju4/ansible-monclient)
[![Build Status - Devel](https://travis-ci.com/juju4/ansible-monclient.svg?branch=devel)](https://travis-ci.com/juju4/ansible-monclient/branches)
# Monitored client ansible role

A simple ansible role to setup system as a monitored client including snmpd, nrpe.
You can use it also to remove configuration.

## Requirements & Dependencies

### Ansible
It was tested on the following versions:
 * 1.9
 * 2.0
 * 2.2
 * 2.5

### Operating systems

Tested with vagrant on Ubuntu 14.04, Kitchen test with trusty and centos7
Targeted for Linux and Darwin

## Example Playbook

Just include this role in your list.
For example

```
- host: all
  roles:
    - juju4.monclient
```

## Variables

```
#monclient_type: nagios
monclient_type: icinga2
monclient_server: ansible_fqdn_servername

## if needed for icinga2 satellite/hosts
#monclient_if: eth0

## define to true if you are on the server itself so we are using localhost
#monclient_useloopback: false

monclient_add_to_etchosts: true

monitor_ntp: true
monitor_mailq_postfix: true
monitor_sensors: false

## to remove server configuration only (use 'gather_facts: False' to avoid online check)
#monclient_remove: true
```

## Continuous integration

This role has a travis basic test (for github), more advanced with kitchen and also a Vagrantfile (test/vagrant).

Once you ensured all necessary roles are present, You can test with:
```
$ cd /path/to/roles/juju4.monclient
$ kitchen verify
$ kitchen login
```
or
```
$ cd /path/to/roles/juju4.monclient/test/vagrant
$ vagrant up
$ vagrant ssh
```

## Troubleshooting & Known issues


## License

BSD 2-clause

