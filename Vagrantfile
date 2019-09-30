#
# based on: https://github.com/andygabby/bionic64-k8s
#
require 'json'

Vagrant.require_version ">= 2.0.0"

servers = YAML.load_file(File.join(File.dirname(__FILE__), 'config/servers.yaml'))

Vagrant.configure('2') do |config|
  config.vm.box = 'generic/ubuntu1804'

  config.vm.provider :libvirt do |v|
    v.memory = 1024
    v.cpus = 2
  end

#  config.trigger.before :up do |trigger|
#    trigger.name = "Removing stale kube-join.sh"
#    trigger.info = "A stale kube-join.sh will prevent the nodes from joining the master"
#    trigger.run = {inline: "bash -c 'if [ -f config/kube-join.sh ]; then rm -f config/kube-join.sh; fi'"}
#  end

  servers['vagrant'].each do |name, server_config|
    config.vm.define name do |host|
      ip = server_config['vm']['ip']
      config.vm.synced_folder '.', '/vagrant', type: 'sshfs'
      host.vm.hostname = name
      host.vm.network :private_network, ip: ip
    end

    if server_config.has_key?('provider') then
      server_config['provider'].each do |provider_config_key, provider_config_value|
        config.vm.provider :libvirt do |host|
          host.send("#{provider_config_key.to_sym}=", "#{provider_config_value}")
        end
      end
    end
  end

  # fix hostname
  servers['vagrant'].each do |name, server_config|
    config.vm.define name do |host|
      host.vm.provision :shell, :inline => "echo 'fix hostname...'", :privileged => true
      host.vm.provision :shell, :inline => 'sudo sed -i "/\b\k8s\b/d" /etc/hosts'
      host.vm.provision :shell, :inline => 'sudo sed -i "/\b\ubuntu1804\b/d" /etc/hosts'
      host.vm.provision :shell, :inline => "sudo echo \"127.0.1.1\t#{name}\n\" >> /etc/hosts"
    end
  end

  # fix dns resolvers
  config.vm.provision :shell, :inline => "sed -i -e 's/4.2.2.2/193.17.47.1/' /etc/netplan/01-netcfg.yaml", :privileged => true
  config.vm.provision :shell, :inline => "sed -i -e 's/4.2.2.1/185.43.135.1/' /etc/netplan/01-netcfg.yaml", :privileged => true
    config.vm.provision :shell, :inline => "sed -i -e 's/, 208.67.220.220//' /etc/netplan/01-netcfg.yaml", :privileged => true

  config.vm.provision :shell, :inline => "netplan apply", :privileged => true

  # run k8s bootstrap
  config.vm.provision :shell, :inline => "echo 'starting bootstrap kubernetes cluster...'", :privileged => true
  config.vm.provision :shell, path: 'config/bootstrap-kube.sh', :privileged => true

end
