# Author::  Guilhem Lettron (<guilhem.lettron@youscribe.com>)
# Contributor:: Kevin MAZIERE (<kevin@kbrwadventure.com>)
# Cookbook Name:: zabbix
# Recipe:: agent_registration
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


  # Ip of the node
  ipadd=(node["cloud"]) ? node["cloud"]["local_ipv4"] : node["ipaddress"]
  ip6add=""
  if node["cloud"]["local_ipv6"]
  ip6add =  node["cloud"]["local_ipv6"]
  node.default['zabbix']['agent']['interfaces'] = [ "zabbix_agentv4", "zabbix_agentv6" ]
  node.save
  end

  # Dns of the node
  dnsname=(node["cloud"]) ? node["cloud"]["local_hostname"] : node["fqdn"]


  #Interface definition
  interface_definitions = {
    :zabbix_agentv4 => {
    :type => 1,
    :main => 1,
    :useip => 1,
    :ip => ipadd,
    :dns => dnsname,
    :port => "10050"
  },
    :zabbix_agentv6 => {
    :type => 1,
    :main => 0,
    :useip => 1,
    :ip => ip6add,
    :dns => dnsname,
    :port => "10050"
  },
    :jmx => {
    :type => 4,
    :main => 1,
    :useip => 1,
    :ip => node['ipaddress'],
    :dns => node['fqdn'],
    :port => "10052"
  },
    :snmp => {
    :type => 2,
    :main => 1,
    :useip => 1,
    :ip => node['ipaddress'],
    :dns => node['fqdn'],
    :port => "161"
  }
  }  

  interface_list = node['zabbix']['agent']['interfaces']

  interface_data = []
  interface_list.each do |interface|
    if interface_definitions.has_key?(interface.to_sym)
      interface_data.push(interface_definitions[interface.to_sym])
    else
      Chef::Log.warn "WARNING: Interface #{interface} is not defined in agent_registration.rb for #{node['hostname']}"
    end
  end

  #Retrieve node template : in attribut node["monitoring"]["zabbix"]"template"]["role_name"]
  tmpl = []
  (node["monitoring"]["zabbix"]["template"] or {}).each do |key,role|
    (role or []).each do |template|
      tmpl << template
    end
  end

  #Retrieve node macros
  macros=[]
  (node["monitoring"]["zabbix"]["macros"] or {}).each do |key,role|
    (role or []).each do |macro|
      macros << macro
    end
  end

  #Create_or_update the host
  zabbix_host "#{node['hostname']}" do
    create_missing_groups true
    server_connection connection_info
    parameters ({
      :host => dnsname,
      :name => node['hostname'],
      :groupNames => node['zabbix']['agent']['groups'],
      :templates => tmpl,
      :interfaces => interface_data,
      :macros => macros.uniq
    })
    action :create_or_update
  end


  #We create a triggers from attribut
  (node["monitoring"]["zabbix"]["triggerdeps"] or {}).each do |t,v|
    Chef::Log.info("Zabbix_LOG : t = #{t} v= #{v}")               
    zabbix_trigger_dependency "#{t}" do
      hostdep_name  v.to_s.split(':', 2).first
      dependency_name  v.to_s.split(':', 2).last[1..-1]
      server_connection connection_info
      trigger_name t
      action :create
    end
  end
end
