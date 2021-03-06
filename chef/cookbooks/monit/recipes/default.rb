#
# Cookbook Name:: monit
# Recipe:: default
#

package "monit" do
  action :install
end

if node["monit"]["mail"]["tls"] != nil
  Chef::Log.warn("node[\"monit\"][\"mail\"][\"tls\"] is deprecated. Use node[\"monit\"][\"mail\"][\"security\"] = 'SSLV2'|'SSLV3'|'TLSV1'")
  unless node["monit"]["mail"]["security"].to_s.empty?
    Chef::Log.warn("node[\"monit\"][\"mail\"][\"security\"] has precedence over deprecated node[\"monit\"][\"mail\"][\"tls\"]")
  end
end


template node["monit"]["main_config_path"] do
  owner  "root"
  group  "root"
  mode   "0700"
  source "monitrc.erb"
  notifies :restart, "service[monit]", :delayed
end

directory "/var/monit" do
  owner "root"
  group "root"
  mode  "0700"
end

if platform_family?("debian")
  # enable startup
  execute "enable-monit-startup" do
    command "/bin/sed s/startup=0/startup=1/ -i /etc/default/monit"
    not_if "grep 'startup=1' /etc/default/monit"
  end
end

# build default monitrc files
node["monit"]["default_monitrc_configs"].each do |conf|
  monit_monitrc conf do
    variables(:category => "system")

    notifies :restart, "service[monit]", :delayed
  end
end

service "monit" do
  action :enable
end
