# Author:: Kevin MAZIERE (<kevin@kbrwadventure.com>)
# Cookbook Name:: zabbix
# Recipe:: template_set
#
# Apache 2.0
#

unless Chef::Config[:solo]
  zabbix_server =search(:node,"role:zabbix-server AND chef_environment:#{node.chef_environment}").first

else
  if node['zabbix']['web']['fqdn']
    zabbix_server = node
  else
    Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
    Chef::Log.warn("If you did not set node['zabbix']['web']['fqdn'], the recipe will fail")
    return
  end
end


if zabbix_server
  apps = []
  search(:apps) do |app|
    (app["server_roles"] & zabbix_server.run_list.roles).each do |app_role|
      #db << data_bag_item("apps",app)
      apps << app
    end
  end

  web_dnsname=""
  apps.each do |a|
    web_dnsname = a['priv_fqdn']
  end

  connection_info = {
    :url => "http://#{web_dnsname}/api_jsonrpc.php",
    :user => zabbix_server['zabbix']['web']['login'],
    :password => zabbix_server['zabbix']['web']['password']
  }

  #Retrieve log file list
  template_zabbix = "Template OS Linux Hypervisor"
  ovhnodes = search(:node, " virtualization_role:host AND chef_environment:#{node.chef_environment}")
  zabbix_application "Network Latency" do
    server_connection connection_info
    action :create
    template "#{template_zabbix}"
  end

  ovhnodes.each do |ovhnode|
    zabbix_item "Fping latency to #{ovhnode['hostname']}" do
      server_connection connection_info
      name "Fping latency to #{ovhnode['hostname']}"
      key "fping.latency.avg[10,200,#{ovhnode['cloud']['local_hostname']}]"
      template "#{template_zabbix}"
      delay 30
      type Zabbix::API::ItemType.zabbix_agent
      value_type Zabbix::API::ItemValueType.float
      history 30
      trends 90
      units  "ms"
      applications ["Network Latency"]
      action :create
    end
  end

end
