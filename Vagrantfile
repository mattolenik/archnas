# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |v|
    v.name = "archnas_test"
  end
  config.vm.box = "generic/arch"

  config.vm.network "forwarded_port", guest: 32400, host: 3240, host_ip: "127.0.0.1"

  config.vm.provision "file", source: "install.sh", destination: "install.sh"
  config.vm.provision "file", source: "vars.sh", destination: "vars.sh"
  config.vm.provision "file", source: "./src", destination: "./src"

  config.vm.provision "shell", inline: <<-SHELL
    pacman --noconfirm -Syu
    ./install.sh
    # run tests
  SHELL
end
