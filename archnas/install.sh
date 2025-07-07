#!/usr/bin/env bash
# shellcheck disable=SC2006
##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
#
# No arguments are needed, guided prompts will follow.
##
# TODO: Set up SMB user and SMB shares
# TODO: Add help
##
set -euo pipefail
[[ -n ${TRACE:-} ]] && set -x && export TRACE

[[ $(uname -r) != *arch* ]] && echo "This script can only run on Arch Linux!" && exit 1

is_test() { [[ -n ${IS_TEST:-} ]]; }

if is_test; then
  # Elevate to root if necessary
  if [[ $EUID != 0 ]]; then exec sudo "$0" "$@"; fi
fi

script_name="${0##*/}"
LOG_FILE="${LOG_FILE:-${script_name%.*}.log}"
exec &> >(tee -a "$LOG_FILE")
trap 'echo ERROR on line $LINENO in $script_name' ERR

IMPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"
source "${IMPORT}/packages.sh"

# UEFI system partition location
export ESP=${ESP:-/boot/efi}

export WINDOWS_WORKGROUP="${WINDOWS_WORKGROUP:-WORKGROUP}"
export SWAPFILE_SIZE="${SWAPFILE_SIZE:-8G}"

install() {
  install_prereqs

  if ! timedatectl list-timezones | grep -q "$TIMEZONE"; then
    fail "Timezone '$TIMEZONE' is not valid"
  fi

  echo

  local system_device
  select_disk system_device
  confirm_disk "$system_device"

  timedatectl set-ntp true

  start_time="$(date +%s)"
  boxbanner "Installing..." "$GREEN$BOLD_"
  echo
  #echo "Output is logged to a file named `green "$LOG_FILE"`"

  local boot_part_size=550
  wipefs -af "$system_device"
  parted "$system_device" mklabel gpt
  parted "$system_device" mkpart primary fat32 1MiB $((1 + boot_part_size))MiB
  parted "$system_device" set 1 esp on
  parted "$system_device" mkpart primary $((1 + boot_part_size))MiB 100%

  local parts
  readarray -t parts < <(sfdisk -J "$system_device" | jq -r '.partitiontable.partitions[].node')
  local boot_part="${parts[0]}"
  local root_part="${parts[1]}"

  # Create partitions
  mkfs.fat -F32 "$boot_part"
  mkfs.btrfs -f -L "system" "$root_part"

  # Always mount root partition before next steps
  mount --mkdir "$root_part" /mnt
  mount --mkdir "$boot_part" "/mnt${ESP}"

  subvolumes=(
    creds # CREDENTIALS_DIRECTORY
    home
    opt
    root
    srv
    var/backups
    var/cache
    var/lib/containers
    var/lib/docker
    var/lib/libvirt
    var/lib/machines
    var/log
    var/opt
    var/tmp
    var/www
  )
  btrfs subvolume create -p "${subvolumes[@]/#//mnt/}"

  # Bootstrap
  pacstrap -K /mnt base "${system_packages[@]}"

  # Copy over supporting files
  rsync -rv "$IMPORT/fs/" /mnt/

  genfstab -U /mnt | tee /mnt/etc/fstab

  # Generate config that can't be stored as static files
  configure_smb
  configure_logging
  configure_network_names

  # The rest of the install is done inside the chroot environment
  local vars=(DOMAIN GITHUB_USERNAME HOST_NAME LOCALE PASSWORD SWAPFILE_SIZE TIMEZONE USER_NAME)
  local scripts=("packages.sh" "common.sh" "inside-chroot.sh")
  export_vars "${vars[@]}" | cat - "${scripts[@]/#/$IMPORT/}" | arch-chroot /mnt /bin/bash

  cp -f /etc/resolv.conf /mnt/etc/resolv.conf

  boxbanner "Done!" "$GREEN$BOLD_"

  local elapsed=$(($(date +%s) - start_time))
  echo "Installation ran for $((elapsed / 60)) minutes and $((elapsed % 60)) seconds"
  echo
  cp -f "$LOG_FILE" /mnt/var/log/install.log
  echo "The installation log will be available at $(green /var/log/install.log)"

  if ! is_test; then
    umount -R /mnt
  fi

  echo $'\nInstallation complete! Rebooting'
  reboot
}

configure_network_names() {
  echo "$HOST_NAME" >/mnt/etc/hostname
  echo "$DOMAIN" >/mnt/etc/domain
}

configure_logging() {
  printf '\nForwardToSyslog=no\n' >>/mnt/etc/systemd/journald.conf
}

configure_smb() {
  mkdir -p /mnt/etc/samba
  cat <<EOF >/mnt/etc/samba/smb.conf
[global]
   workgroup = $WINDOWS_WORKGROUP
   server string = ArchNAS Samba Server %v
   server role = standalone server
   security = user
   map to guest = never
   dns proxy = no
   logging = systemd
   netbios name = $HOST_NAME
EOF
}

install_prereqs() {
  printf "Installing prereqs..."
  pacman -Sy --noconfirm jq &>/dev/null || fail "prerequisite jq failed to install"
  printf "done\n\n"
}

confirm_disk() {
  if [[ -n ${AUTO_APPROVE:-} ]]; then return 0; fi
  local continue
  echo "$(red NOTICE:) ArchNAS is about to be installed onto disk: $(red "$1")"
  echo "Continue? This will $(red DESTROY) any existing data."
  read -rp "Type YES to proceed, or anything else to abort: " continue
  if [[ $continue != "YES" ]]; then
    fail "Aborting installation"
  fi
}

# Find available, writeable disks for install. It will print
# the following columns: name, size, model
list_disks() {
  lsblk -o type,ro,name,size,model -nrd |
    awk '/^disk 0/ {printf "/dev/%s %s %s\n", $3, $4, $5}' |
    sort |
    column -t |
    sed -E -e 's/\\x20/ /g' -e 's/[ ]+$//'
}

# Show a menu selection of disks and return the corresponding device file.
# $1 - out variable that will store the result
select_disk() {
  if [[ -n ${AUTO_APPROVE:-} ]]; then
    if [[ -z ${TARGET_DISK:-} ]]; then
      fail "Target disk must be specified when using auto-approve"
    fi
    read -r "$1" <<<"$TARGET_DISK"
    return 0
  fi

  echo "Choose a disk to auto-partition. Any existing data will be lost. Press CTRL-C to abort."
  PS3=$'\nChoose disk #) '
  IFS=$'\n'
  trap 'unset PS3; unset IFS' RETURN

  local disks
  mapfile -t disks < <(list_disks)
  select disk in "${disks[@]}"; do
    # If input is a number and within the range of options
    if [[ $REPLY =~ ^[0-9]$ ]] && ((REPLY > 0)) && ((REPLY <= ${#disks[@]})); then
      read -r "$1" < <(echo "$disk" | awk '{print $1}')
      break
    else
      echo "That's not a valid option, please choose again."
    fi
  done
}

export_vars() {
  for var in "$@"; do
    echo "export $var=\"${!var}\""
  done
}

install
