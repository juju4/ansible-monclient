require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package('acl') do
  it { should be_installed }
end


