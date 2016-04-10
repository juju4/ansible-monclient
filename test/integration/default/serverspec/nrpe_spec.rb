#require 'spec_helper'
require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package('nrpe'), :if => os[:family] == 'redhat' do
  it { should be_installed }
end

describe package('nagios-nrpe-server'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe service('nrpe'), :if => os[:family] == 'redhat' do
  it { should be_enabled }
  it { should be_running }
end

describe service('nagios-nrpe-server'), :if => os[:family] == 'ubuntu' do
  it { should be_enabled }
  it { should be_running }
end

#describe service('org.apache.httpd'), :if => os[:family] == 'darwin' do
#  it { should be_enabled }
#  it { should be_running }
#end

describe port(5666) do
  it { should be_listening }
end

