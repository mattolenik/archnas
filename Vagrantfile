# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure('2') do |config|
  config.vm.box = 'generic/arch'
  # Plex
  config.vm.network 'forwarded_port', guest: 32400, host: 3240, host_ip: '127.0.0.1'

  config.vm.provider 'virtualbox' do |v|
    v.name = ENV['VM_NAME'] || 'archnas_vagrant'
    v.customize ['storagectl', :id, '--name', 'SATA Controller', '--add', 'sata']

    # Get disk path
    vb_machine_folder = %x(tools/get-vbox-machine-dir).chomp
    second_disk = File.join(vb_machine_folder, v.name, 'install_disk.vmdk')

    # Create and attach disk
    if !File.exist? second_disk
      v.customize ['createhd', '--filename', second_disk, '--format', 'vmdk', '--size', 32 * 1024]
    end
    v.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 0, '--device', 0, '--type', 'hdd', '--medium', second_disk]
  end

  config.vm.provision 'shell', inline: <<-SHELL
    set -euo pipefail
    # Some prereqs are missing that are normally present on the Arch live CD
    # pacman --noconfirm -Syu --ignore=kernel --ignore=kernel-headers
    pacman --noconfirm -Sy arch-install-scripts btrfs-progs dosfstools parted
  SHELL
end
