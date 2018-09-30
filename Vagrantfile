# -*- mode: ruby -*-
# vi: set ft=ruby :

# This Vagrant VM verifies the installation and configuration of ArchNAS.
Vagrant.configure('2') do |config|
  config.vm.box = 'archnas/archnas'
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provider 'virtualbox' do |v|
    v.name = 'archnas_test'
    v.customize ['modifyvm', :id, '--firmware', 'efi']
  end

  config.vm.provision 'file', source: 'test', destination: '.'

  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
  set -euo pipefail
  # Install Bats and add it to the path
  sudo -S bats/install.sh "$HOME" <<< "vagrant"
  echo 'export PATH="$HOME/bin:$PATH" >> "$HOME/.bashrc"
  SHELL
end
