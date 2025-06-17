#!/usr/bin/env bash

system_packages=(
  base-devel
  bash
  bash-completion
  bat                   # cat alternative
  bind-tools
  btrfs-progs
  ca-certificates
  ca-certificates-mozilla
  ca-certificates-utils
  cifs-utils
  cni-plugins
  cockpit
  cockpit-files
  cockpit-machines
  cockpit-packagekit
  cockpit-podman
  cockpit-storaged
  dosfstools
  duf                   # df alternative
  dust                  # du alternative
  efibootmgr
  fd                    # find alternative
  figlet                # Prints ASCII art text and banners
  fzf                   # fuzzy finder
  git
  go
  grub
  grub-btrfs
  htop                  # improved top
  hyperfine             # benchmarking tool
  intel-media-driver
  intel-ucode
  jq
  lf                    # file browser similar to ranger
  libfido2
  libutil-linux
  libva-intel-driver
  libvdpau-va-gl
  libvirt               # Virtualization
  linux-firmware
  linux
  linux-headers
  lm_sensors
  lsd                   # ls alternative
  lsof
  monit                 # monitoring service
  moreutils             # misc utils including sponge
  #mosh
  neovim
  gnu-netcat
  netdata
  nut                   # Network UPS Tools
  openssh
  parallel
  parallel-docs
  pass                  # Password manager
  podman
  podman-compose
  #podman-dnsname
  podman-docker
  procs                 # ps alternative
  python
  python-pip
  rdma-core
  ripgrep               # grep alternative
  rsync
  ruby
  ruby-erb
  samba
  smartmontools
  snapper               # snapshot manager
  starship              # fancy prompt for bash and zsh
  sudo
  tmux
  tree
  ufw                   # firewall
  wget
  xh                    # httpie alternative
  yq                    # like jq but for yaml
  zsh
  zsh-completions
)

aur_packages=(
  mkinitcpio-firmware   # Common firmware
  plex-media-server
  rcm                   # dotfile manager
  zfs-dkms
  zfs-utils
)

