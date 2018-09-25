# -*- mode: ruby -*-
# vi: set ft=ruby :
install_disk='dist/install_disk.vdi'

Vagrant.configure('2') do |config|
  config.vm.box = 'generic/arch'

  config.vm.provider 'virtualbox' do |v|
    v.name = ENV['VM_NAME'] || 'archnas_vagrant'
    v.customize ['storagectl', :id, '--name', 'SATA Controller', '--add', 'sata']

    # Create a disk and attach it. ArchNAS will be installed onto this disk.
    if !File.exist? install_disk
      v.customize ['createhd', '--filename', install_disk, '--format', 'vdi', '--size', 24 * 1024]
    end
    v.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 0, '--device', 0, '--type', 'hdd', '--medium', install_disk]
  end

  config.vm.provision 'file', source: './src', destination: '.'

  config.vm.provision 'shell', inline: <<-SHELL
    set -euo pipefail

    # Some prereqs are missing that are normally present on the Arch live CD
    pacman --noconfirm -Sy arch-install-scripts btrfs-progs dosfstools parted

    # Start the installation
    ./install.sh --auto-approve --username vagrant --password vagrant --target-disk /dev/sdb
  SHELL

  config.vm.provision 'shell', inline: <<-SHELL
    set -euo pipefail
    ##
    # The install disk will be remounted by another Vagrant VM, which will
    # boot and verify the installation. VBox will execute startup.nsh upon
    # boot, which in turn loads GRUB, which ultimately boots the new system.
    ##
    echo 'fs0:EFI\\GRUB\\grubx64.efi' > /mnt/boot/startup.nsh

    # Allow Vagrant to connect over SSH
    mkdir -p /mnt/home/vagrant/.ssh
    echo '#{File.read("vagrant.pub").chomp}' >> /mnt/home/vagrant/.ssh/authorized_keys

    umount -R /mnt
  SHELL
end
