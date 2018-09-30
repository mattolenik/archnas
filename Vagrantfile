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
end
