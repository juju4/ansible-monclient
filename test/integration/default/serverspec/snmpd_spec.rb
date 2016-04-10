#require 'spec_helper'
require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package('net-snmp'), :if => os[:family] == 'redhat' do
  it { should be_installed }
end

describe package('snmpd'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe service('snmpd'), :if => os[:family] == 'redhat' do
  it { should be_enabled }
  it { should be_running }
end

describe service('snmpd'), :if => os[:family] == 'ubuntu' do
  it { should be_enabled }
  it { should be_running }
end

#describe service('org.apache.httpd'), :if => os[:family] == 'darwin' do
#  it { should be_enabled }
#  it { should be_running }
#end

describe port(161) do
  it { should be_listening }
end

