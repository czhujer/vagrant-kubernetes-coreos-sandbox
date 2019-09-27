# Size of the cluster created by Vagrant
num_instances=3

# Change basename of the VM
instance_name_prefix="k8s-node"

require 'json'

Vagrant.require_version ">= 2.0.0"

ignition_file = File.join(File.dirname(__FILE__), 'config.ign')

config = {
  :ignition => {
    :version => "2.2.0",
  },
  :passwd => {
    :users => [{
      :name => 'core',
      #:sshAuthorizedKeys => ['ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key'],
      :sshAuthorizedKeys => [
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCv+x4NKHMrFaS1VR71pnsGSq6en2EgmGBS3hHMm0l2AYBBwOVO2byokFo93w2IIe0tnJ+QerezGsAm1pGHrbx2HiTWF9uD+RyFQCQN0LKx1soMhEGryvjpS7rgDVMeCNn0Ej28m+NR1+6jhg4gA38c42ZZCcNd89pcpVWsMNpO/RVk25DfS/M5BJkUQMOoiMVwby0tJ62jh83fgzDMukynmA8xOX9D/uvL1kamEzbsA6Ioh8QRdBt4mlO6tnR6WxHTvGU5IHgE01Qm27s+YJpegH93VU0rxysGMGPd0VgvDHJmnR0l+ZR9d9T/iMzjxXw2ZX6FpG8JxwdAb9Wd2dySwFKZBwAXPtjm5GUTw22tk+gdk7FfgA2fjFeHGAVswX1loIREXMKpSuerGIrtroQwwBAEgnT84jqFnBYb5ApypaeKSQR1m6ZVnNjjBfj7t19lr+/hSRyorYZoGgFuryBY7R1UOH7zNAEnJlCLv7yab9ERCCwwukhP+nWoTjy6Fv+aF49LJpqiAbDV76TxAzjxvrFl4vv09NnVHVmYcIOaJuLWDmqS7CcLb8piFbcLvgTMxuN3OFZ0ybVfjA55bn9fPD2yIt57htwoaMU4sR3ULiybw6EAiIwJJT3Gq5WZ42Yh7G4WJIlnXCAy/4RL2Rtq/irXoaxn2Uw+KI0I5GkAOw== czhujer@czhujer-Latitude-5490',
        'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant',
      ],
      :passwordHash => "$6$SfuvSSLq$YJe.Qtnglb7Ct2oCSU1qlMWZOmWzGiN.Ue53gLe4rZ6meV9wv6rpt8LZEd4uGBsPqvR/I/UPNRunR4vjSw6jI1",
    }],
  },
#  :storage => {
#    :files => [{
#      :filesystem => "root",
#      :path       => "/etc/hostname",
#      :mode       => 0644,
#      :contents   => {
#        inline: "",
#      }
#    }],
#  }
#    files:
#      - filesystem: "root"
#        path:       "/etc/hostname"
#        mode:       0644
#        contents:
#          inline: alg-core-s1

}

File.open(ignition_file, "w") { |file| file.puts JSON.generate(config)}

# Official CoreOS channel from which updates should be downloaded
#update_channel='stable'

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false

  config.vm.box = "coreos_stable_prod"
  #config.vm.box_version = ">= 1122.0.0"
  #config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % update_channel

  config.ssh.username = "core"

  config.vm.provider :libvirt do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    #v.check_guest_additions = false
    v.memory = 1024
    v.cpus = 2
    #v.functional_vboxsf     = false

    v.qemuargs :value => '-fw_cfg'
    v.qemuargs :value => "name=opt/com.coreos/config,file=#{ignition_file}"
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  # Set up each box
  (1..num_instances).each do |i|
    if i == 1
      vm_name = "k8s-master"
    else
      vm_name = "%s-%02d" % [instance_name_prefix, i-1]
    end

    config.vm.define vm_name do |host|
      host.vm.hostname = vm_name

      ip = "172.18.18.#{i+100}"
      host.vm.network :private_network, ip: ip
      # Workaround VirtualBox issue where eth1 has 2 IP Addresses at startup
      #host.vm.provision :shell, :inline => "sudo /usr/bin/ip addr flush dev eth1"
      #host.vm.provision :shell, :inline => "sudo /usr/bin/ip addr add #{ip}/24 dev eth1"

      host.vm.provision :shell, :inline => "sudo mkdir -p /media/state/units"

      if i == 1
        # Configure the master.
        host.vm.provision :file, :source => "master-config.yaml", :destination => "/tmp/vagrantfile-user-data"
        host.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

        host.vm.provision :shell, :inline => "echo '127.0.0.1\tlocalhost' > /etc/hosts", :privileged => true
        host.vm.provision :shell, :inline => "mkdir -p /etc/kubernetes/manifests/", :privileged => true
      else
        # Configure a node.
        host.vm.provision :file, :source => "node-config.yaml", :destination => "/tmp/vagrantfile-user-data"
        host.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end
    end
  end
end
