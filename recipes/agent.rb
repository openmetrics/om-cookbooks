#
# Cookbook Name:: openmetrics
# Recipe:: agent
#

om_home = '/home/openmetrics'
om_agent_basedir = '/opt/openmetrics-agent'
om_hostname = ` hostname --fqdn `
om_download_url = 'http://download.openmetrics.net/'


# create system user and group
#
# https://docs.chef.io/resource_user.html
# https://docs.chef.io/resource_group.html
group "om" do
  action :create
  group_name 'om'
end

user 'om-agent' do
  action :create
  comment 'Openmetrics Agent user'
  supports :manage_home => true
  home om_home
  shell '/bin/bash'
  gid 'om'
end

# verify user home exists
directory "#{om_home}" do
    path om_home
    owner 'om'
    group 'om'
    mode 0755
    action :create
end


#
# create SSH keys
#
chef_gem 'sshkey' do 
  compile_time false # https://www.chef.io/blog/2015/02/17/chef-12-1-0-chef_gem-resource-warnings/
end
# Base location of ssh key
pkey = om_home + '/.ssh/id_rsa'

# Generate a keypair with Ruby
require 'sshkey'
sshkey = SSHKey.generate(
  type: 'RSA',
  comment: "om@#{om_hostname}"
)

# Create ~/.ssh directory
directory "#{om_home}/.ssh" do
  owner 'om'
  group 'om'
  mode 00700
end

# store SSH private key on disk
template pkey do
  owner 'om'
  group 'om'
  variables(ssh_private_key: sshkey.private_key)
  mode 00600
  action :create_if_missing
end

# store SSH public key on disk
template "#{pkey}.pub" do
  owner 'om'
  group 'om'
  variables(ssh_public_key: sshkey.ssh_public_key)
  mode 00644
  action :create_if_missing
end

# fetch and install openmetrics-agent package
openmetrics_agent_latest = "#{Chef::Config[:file_cache_path]}/openmetrics-agent.deb"
remote_file openmetrics_agent_latest do
   source "#{om_download_url}/openmetrics-agent_latest.deb"
   action :create
end
dpkg_package "openmetrics-agent" do
  source openmetrics_agent_latest
  action :install
end

# make sure openmetrics-agent files belong to om user
# TODO get user and group from attributes
execute "chown-om" do
  command "chown -R om-agent:om #{om_agent_basedir}"
  user "root"
  action :run
  not_if "stat -c %U #{om_agent_basedir} |grep om-agent"
end

