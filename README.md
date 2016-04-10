[![Build Status](https://travis-ci.org/juju4/ansible-monclient.svg?branch=master)](https://travis-ci.org/juju4/ansible-monclient)
# Monitored client ansible role

A simple ansible role to setup system as a monitored client including
snmpd
nrpe

## Requirements & Dependencies

### Ansible
It was tested on the following versions:
 * 1.9
 * 2.0

### Operating systems

Tested with vagrant on Ubuntu 14.04, Kitchen test with trusty and centos7
Targeted for Linux and Darwin

## Example Playbook

Just include this role in your list.
For example

```
- host: all
  roles:
    - monclient
```

## Variables

```

---
#monclient_type: nagios
monclient_type: icinga2
monclient_server: ansible_fqdn_servername

## if needed for icinga2 satellite/hosts
#monclient_if: eth0

## define to true if you are on the server itself so we are using localhost
#monclient_useloopback: false

## / can be a catchall so better to put device
##  Ensure it is defined in local-nrpe.cfg
monclient_partitionroot: sda1
monclient_partitionboot: sda2
## for icinga2
#monclient_group: Group1
#monclient_checkcommand: hostalive
#monclient_checkcommand: tcp

## snmp community
monclient_snmpcommunity: public

## nrpe bind restriction (only accept one IP)
#monclient_nrpebind: '192.168.250.10'
## nrpe allowed hosts
monclient_nrpeserver: '192.168.0.1'

monclient_add_to_etchosts: true

monitor_ntp: true
monitor_mailq_postfix: true
monitor_sensors: false

```

## Continuous integration

This role has a travis basic test (for github), more advanced with kitchen and also a Vagrantfile (test/vagrant).

Once you ensured all necessary roles are present, You can test with:
```
$ cd /path/to/roles/monclient
$ kitchen verify
$ kitchen login
```
or
```
$ cd /path/to/roles/monclient/test/vagrant
$ vagrant up
$ vagrant ssh
```

## Troubleshooting & Known issues


## License

BSD 2-clause
