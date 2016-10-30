require 'serverspec'

# Required by serverspec
set :backend, :exec

## in harden role
#describe package('logcheck') do
#  it { should be_installed }
#end

describe file('/etc/logcheck/ignore.d.workstation/monserver'), :if => os[:family] == 'debian' do
  it { should be_file }
end


