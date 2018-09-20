# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "generic/arch"
  # Plex
  config.vm.network "forwarded_port", guest: 32400, host: 3240, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |v|
    v.name = "archnas_test"

    # Get disk path
    vb_machine_folder = `VBoxManage list systemproperties | awk '/Default machine folder/ {match($0, /:[[:blank:]]+(.*)/, a); print a[1]}'`
    second_disk = File.join(vb_machine_folder, v.name, 'archnas_test_install_disk.vdi')

    # Create and attach disk
    unless File.exist?(second_disk)
      v.customize ['createhd', '--filename', second_disk, '--format', 'VDI', '--size', 8 * 1024]
    end
    v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 0, '--device', 1, '--type', 'hdd', '--medium', second_disk]
  end

  config.vm.provision "file", source: "install.sh", destination: "install.sh"
  config.vm.provision "file", source: "vars.sh", destination: "vars.sh"
  config.vm.provision "file", source: "./src", destination: "./src"

  config.vm.provision "shell", inline: <<-SHELL
    pacman --noconfirm -Syu
    ./install.sh
    # run tests
  SHELL
end
