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
  imfilenode = search(:node, "imfile:files AND chef_environment:#{node.chef_environment}")
  runitnode = search(:node, "runit:apps AND chef_environment:#{node.chef_environment}")
  appli = search(:apps)
  list_file = []
  delay=(node['monitoring']['zabbix-conf']) ? node['monitoring']['zabbix-conf']['templates']['Template KBRW Log files']["#{(logfile.split('APPS/').last).gsub('/','_')}"] : 120
  doit=(node['monitoring']['zabbix-conf']) ? node['monitoring']['zabbix-conf']['templates']['Template KBRW Log files']['action'] : "create"
  nocheck="-error|munin|crawler|mysql_err|runit.sa_wiki"
  # Log imfile (via apache et attribut chef)
  (imfilenode.sort or []).sort.each do |n|
    (n['rsyslog']['imfile']['files'] or {}).sort.each do |name,file|
      list_file << node['rsyslog']['log_dir']+"/"+node['rsyslog']['apps_dir']+"/"+file['app_name']+"/"+file['remote_file']
      logfile = node['rsyslog']['log_dir']+"/"+node['rsyslog']['apps_dir']+"/"+file['app_name']+"/"+file['remote_file']
      unless logfile =~ /#{nocheck}/

        # We create node apps and node logfile check
        zabbix_application "LogFiles" do
          server_connection connection_info
          action :create
          hostname "#{n['cloud']['local_hostname']}"
        end

        zabbix_item "syslog-#{file['name']}-time" do
          server_connection connection_info
          name "Modify "+file['path']+"/"+file['name']
          key "vfs.file.time[#{file['path']}/#{file['name']},modify]"
          hostname "#{n['cloud']['local_hostname']}"
          delay delay
          type Zabbix::API::ItemType.zabbix_agent
          value_type Zabbix::API::ItemValueType.float
          history 4
          trends 8
          applications ["LogFiles"]
          action :create
        end
        if logfile=~/APPS/
          logfile=logfile.gsub(/%.*APPS/,'Apps_today')
        end
        if logfile=~/SYSTEM/
          logfile=logfile.gsub(/%.*SYSTEM/,'System_today')
        end
        zabbix_item "syslog-#{file['name']}-modify" do
          server_connection connection_info
          template "Template KBRW Log files"
          name "Modify "+(logfile.split('/')[-2..-1]).join('_')
          key "vfs.file.time[#{logfile},modify]"
          #look a modify time should be equivalent to stat -c %Y file
          #update each 1h
          delay delay
          #Zabbix agent
          type Zabbix::API::ItemType.zabbix_agent
          #numeric float 
          value_type Zabbix::API::ItemValueType.float
          history 4
          trends 8
          applications ["LogFiles"]
          action :"#{doit}"
        end
        zabbix_item "syslog-#{file['name']}-diff" do
          server_connection connection_info
          name "Log_Diff "+n['cloud']['local_hostname'].split('.').first+'.'+file['name']
          key "log_diff."+n['cloud']['local_hostname']+'.'+file['name']
          hostname "#{node['cloud']['local_hostname']}"
          delay delay
          item_params "last(\"#{n['cloud']['local_hostname']}:vfs.file.time[#{file['path']}/#{file['name']},modify]\")-last(\"vfs.file.time[#{logfile},modify]\")"
          type Zabbix::API::ItemType.calculated
          value_type Zabbix::API::ItemValueType.float
          history 4
          trends 8
          applications ["LogFiles"]
          action :create
        end
      end
    end
  end

  # Log runit via runit
  (runitnode or []).sort.each do |n|
    unless n['runit']['apps'].nil? ||  n['rsyslog'].nil? || n['rsyslog']['log_dir'].nil? || n['rsyslog']['apps_dir'].nil?
      (n['runit']['apps'] or {}).each do |apps,value|
        list_file << node['rsyslog']['log_dir']+"/"+node['rsyslog']['apps_dir']+"/"+apps+"/runit_"+apps+".log"
        logfile = node['rsyslog']['log_dir']+"/"+node['rsyslog']['apps_dir']+"/"+apps+"/runit_"+apps+".log"
        unless logfile =~ /#{nocheck}/
          # We create node apps and node logfile check
          zabbix_application "LogFiles" do
            server_connection connection_info
            action :create
            hostname "#{n['cloud']['local_hostname']}"
          end
          if value == true
            zabbix_item "syslog-#{apps}-time" do
              server_connection connection_info
              name "Modify "+apps+"/current"
              key "vfs.file.time[/var/log/#{apps}/current,modify]"
              hostname "#{n['cloud']['local_hostname']}"
              delay 3600
              type Zabbix::API::ItemType.zabbix_agent
              value_type Zabbix::API::ItemValueType.float
              history 4
              trends 8
              applications ["LogFiles"]
              action :create
            end
            if logfile=~/APPS/
              logfile=logfile.gsub(/%.*APPS/,'Apps_today')
            end
            if logfile=~/SYSTEM/
              logfile=logfile.gsub(/%.*SYSTEM/,'System_today')
            end
            zabbix_item "syslog-#{apps}-modify" do
              server_connection connection_info
              template "Template KBRW Log files"
              name "Modify "+(logfile.split('/')[-2..-1]).join('_')
              key "vfs.file.time[#{logfile},modify]"
              #look a modify time should be equivalent to stat -c %Y file
              #update each 1h
              delay delay
              #Zabbix agent
              type Zabbix::API::ItemType.zabbix_agent
              #numeric float 
              value_type Zabbix::API::ItemValueType.float
              history 4
              trends 8
              applications ["LogFiles"]
              action :"#{doit}"
            end

            zabbix_item "syslog-#{apps}-diff" do
              server_connection connection_info
              name "Log_Diff "+n['cloud']['local_hostname'].split('.').first+'.'+'runit_'+apps
              key "log_diff."+n['cloud']['local_hostname']+'.'+'runit.'+apps
              hostname "#{node['cloud']['local_hostname']}"
              delay delay
              item_params "last(\"#{n['cloud']['local_hostname']}:vfs.file.time[/var/log/#{apps}/current,modify]\")-last(\"vfs.file.time[#{logfile},modify]\")"
              type Zabbix::API::ItemType.calculated
              value_type Zabbix::API::ItemValueType.float
              history 4
              trends 8
              applications ["LogFiles"]
              action :create
            end
          end
        end
      end
    end
  end
  appli.each do |db|
    unless db["specificConfiguration"].nil? || db["specificConfiguration"][node.chef_environment].nil? ||  db["specificConfiguration"][node.chef_environment]["logs"].nil?
      db["specificConfiguration"][node.chef_environment]["logs"].each do |name,log|
        list_file << node['rsyslog']['log_dir']+"/"+node['rsyslog']['apps_dir']+"/"+db["id"]+"/"+log["filename"]
        #        zabbix_application "LogFiles" do
        #          server_connection connection_info
        #          action :create
        #          hostname "#{n['cloud']['local_hostname']}"
        #        end
        #
        #        zabbix_item "syslog-#{file['name']}" do
        #          server_connection connection_info
        #          name "Modify "+file['path']+file['name']
        #          key "vfs.file.time[#{file['path'}/#{file['name']},modify]"
        #          hostname "#{n['cloud']['local_hostname']}"
        #          delay 3600
        #          #Zabbix agent
        #          type Zabbix::API::ItemType.zabbix_agent
        #          #numeric float 
        #          value_type Zabbix::API::ItemValueType.float
        #          history 4
        #          trends 8
        #          applications ["LogFiles"]
        #          action :create
        #        end
      end
    end
  end

  #log "Delay agent registration to wait for server to be started" do
  #  level :debug
  #  notifies :create_or_update, "zabbix_host[#{node['zabbix']['agent']['hostname']}]", :delayed
  #end
  zabbix_application "LogFiles" do
    server_connection connection_info
    action :create
    template "Template KBRW Log files"
  end
  #Chef::Log.warn("Zabbix Trigger Logs : #{list_file}")
  Chef::Log.info("Zabbix : Trigger Logs Total : #{list_file.uniq.length}")

  list_file.uniq.each do |logfile|
    unless logfile =~ /#{nocheck}/
      if logfile=~/APPS/
        logfile=logfile.gsub(/%.*APPS/,'Apps_today')
      end
      if logfile=~/SYSTEM/
        logfile=logfile.gsub(/%.*SYSTEM/,'System_today')
      end
      zabbix_item "syslog" do
        server_connection connection_info
        template "Template KBRW Log files"
        name "Modify "+(logfile.split('/')[-2..-1]).join('_')
        key "vfs.file.time[#{logfile},modify]"
        #look a modify time should be equivalent to stat -c %Y file
        #update each 1h
        delay delay
        #Zabbix agent
        type Zabbix::API::ItemType.zabbix_agent
        #numeric float 
        value_type Zabbix::API::ItemValueType.float
        history 4
        trends 8
        applications ["LogFiles"]
        action :"#{doit}"
      end

      zabbix_item "syslog-exist" do
        server_connection connection_info
        template "Template KBRW Log files"
        name "Exist "+(logfile.split('/')[-2..-1]).join('_')
        key "vfs.file.exists[#{logfile}]"
        delay delay
        #Zabbix agent
        type Zabbix::API::ItemType.zabbix_agent
        #numeric float 
        value_type Zabbix::API::ItemValueType.float
        history 4
        trends 8
        applications ["LogFiles"]
        action :"#{doit}"
      end

      zabbix_trigger "syslog-fileexist" do
        server_connection connection_info
        name ("File missing :"+(logfile.split('/')[-2..-1]).join('/'))
        type Zabbix::API::TriggerType.normal
        priority Zabbix::API::TriggerPriority.information
        expression "{Template KBRW Log files:vfs.file.exists[#{logfile}].last()}=0"
        template  "Template KBRW Log files" 
        #        action :"#{node['monitoring']['zabbix-conf']['templates']['Template KBRW Log files']['action']}"
        action :nothing
      end
    end

    #    zabbix_trigger "syslog" do
    #      server_connection connection_info
    #      name ("Last event on :"+(logfile.split('/')[-2..-1]).join('/'))
    #      type Zabbix::API::TriggerType.normal
    #      priority Zabbix::API::TriggerPriority.information
    #      expression "{Template KBRW Log files:vfs.file.time[#{logfile},modify].change(0)}#0"
    #      template  "Template KBRW Log files" 
    #      action :"#{node['monitoring']['zabbix-conf']['templates']['Template KBRW Log files']['action']}"
    #    end
    #
  end
end
