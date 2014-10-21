# Author:: Nacer Laradji (<nacer.laradji@gmail.com>)
# Cookbook Name:: zabbix
# Recipe:: server
#
# Copyright 2011, Efactures
#
# Apache 2.0
#

include_recipe "zabbix::server_#{node['zabbix']['server']['install_method']}"

### DATA BELOW ARE FOR REMEMBER IN CASE OF A MASS CRASH; THEY ARE SET INTO CHEF ROLE"

#Template for zabbix server
#node.default["monitoring"]["zabbix"]["template"] = (node.default["monitoring"]["zabbix"]["template"] << '"Template App Zabbix Server"')

#Template for dns monitoring from outside
#node.default["monitoring"]["zabbix"]["template"] = (node.default["monitoring"]["zabbix"]["template"] << '"Template DNS KBRW External"')

#Template for mysql db
#node.default["monitoring"]["zabbix"]["template"] = (node.default["monitoring"]["zabbix"]["template"] << '"Template App MySQL"')
#Firewalll rules, only for prod

if node.chef_environment == '_default'
  require 'resolv'

  fqdns = []
  fqdns << node['cloud']['local_hostname']
  ipv4_address=""
  ipv6_address=""
  dns_node = search(:node, 'role:dns').first

  #Resolver local n'est pas suffisant
  resolver = Resolv::DNS.new(:nameserver => ["#{dns_node['cloud']['local_hostname']}"])
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
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_80']['action']='ACCEPT'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_80']['dport']='80'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_80']['proto']='tcp'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_80']['comment']="#{node['hostname']}: Monitoring server tcp 80"
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_80']['sip']='172.16.0.1'
      
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_443']['action']='ACCEPT'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_443']['dport']='443'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_443']['proto']='tcp'
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_443']['comment']="#{node['hostname']}: Monitoring server tcp 443"
      node.default['firewall']['iptables']['FORWARD']["#{ipv4_address}"]['zabbix_server_443']['sip']='172.16.0.1'
    end
    if !ipv6_address.empty?
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_80']['action']='ACCEPT'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_80']['dport']='80'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_80']['proto']='tcp'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_80']['comment']="#{node['hostname']}: Monitorig server tcp 80"
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_80']['sip']='2001:41d0:009a:0a00::0/64'
      
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_443']['action']='ACCEPT'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_443']['dport']='443'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_443']['proto']='tcp'
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_443']['comment']="#{node['hostname']}: Monitorig server tcp 443"
      node.default['firewall']['ip6tables']['FORWARD']["#{ipv6_address}"]['zabbix_server_443']['sip']='2001:41d0:009a:0a00::0/64'
    end
  end
else
  Chef::Log.warn("Zabbix : No firewall, server is not a prod server")
end

