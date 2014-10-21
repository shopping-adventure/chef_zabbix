#include_recipe "zabbix::agent_#{node['zabbix']['agent']['install_method']}"
#include_recipe "zabbix::agent_common"

zabbix_server =search(:node,"role:zabbix-server AND chef_environment:#{node.chef_environment}").first

#unless zabbix_server.length.nil?
if zabbix_server
  include_recipe "zabbix::agent_#{node['zabbix']['agent']['install_method']}"
  include_recipe "zabbix::agent_common"

  zabbix_server =search(:node,"role:zabbix-server AND chef_environment:#{node.chef_environment}").first

  node.default["monitoring"]["zabbix"]["template"]["base"]= ['Template OS Linux Base']

  # Install configuration
  template "zabbix_agentd.conf" do
    path node['zabbix']['agent']['config_file']
    source "zabbix_agentd.conf.erb"
    unless node['platform_family'] == "windows"
      owner "root"
      group "root"
      mode "644"
    end
    notifies :restart, "service[zabbix-agent]"
    variables({
      :zabbix_server => zabbix_server
    })
  end

  ruby_block "start service" do
    block do
      true
    end
    Array(node['zabbix']['agent']['service_state']).each do |action|
      notifies action, "service[zabbix-agent]"
    end
  end

  res=search(:virtual_machines,"id:#{node['hostname']}").first
  if res then
    hyp=res["host"]
    # Dirty trick to set end of fqdn hypervisor same as vm
    if node["cloud"]["local_hostname"]
      hyp=hyp.to_s.split('.', 2).first+"."+node["cloud"]["local_hostname"].to_s.split('.', 2).last
    end		
    #Setup hyp trigger dependencies here
    node.default['virtualization']['hypervisor']="#{hyp}"
    node.default['monitoring']['zabbix']['triggerdeps']["{HOST.NAME} : Ping ICMP"]= "#{hyp}: {HOST.NAME} : Ping ICMP"
    node.default['monitoring']['zabbix']['triggerdeps']["Lack of available memory on server {HOST.NAME}"]= "#{hyp}: Lack of available memory on server {HOST.NAME}"
  else
    Chef::Log.warn("Zabbix_LOG : #{node['hostname']} as not hypervisor defined in it's databags")
  end

  package "libnet-dns-perl"

end

#Firewalll rules, only for prod

if node.chef_environment == '_default'
  require 'resolv'

  fqdns = []
  fqdns << node['cloud']['local_hostname']
  ipv4_address=""
  ipv6_address=""
  dns_node = search(:node, 'role:dns').first

  #Resolver local n'est pas suffisant
  #resolver = Resolv::DNS.new(:nameserver => ["#{dns_node['cloud']['local_hostname']}"])
  resolver = Resolv::DNS.new(:nameserver => "8.8.8.8")
  fqdns.each do |fqdn|
    resolver.getaddresses("#{fqdn}").each do |ip|
      case ip.to_s
      when Resolv::IPv4::Regex
        ipv4_address=ip.to_s
      when Resolv::IPv6::Regex
        ipv6_address=ip.to_s
      end
    end
    #Define Firewall attribut
    if !ipv4_address.empty?
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_agent']['action']='ACCEPT'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_agent']['dport']=node['zabbix']['agent']['listen_port']
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_agent']['proto']='tcp'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_agent']['comment']="#{node['hostname']}: Zabbix agent tcp"
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_agent']['sip']=zabbix_server['cloud']['local_ipv4']
    end
    if !ipv6_address.empty?
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_agent']['action']='ACCEPT'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_agent']['dport']=node['zabbix']['agent']['listen_port']
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_agent']['proto']='tcp'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_agent']['comment']="#{node['hostname']}: Zabbix agent tcp"
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_agent']['sip']=zabbix_server['cloud']['local_ipv6']
    end
  end
else
  Chef::Log.warn("Zabbix : No firewall, server is not a prod server")
end

