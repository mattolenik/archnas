btrfs subvolume create -p /swap
btrfs filesystem mkswapfile --size "$SWAPFILE_SIZE" /swap/swapfile
swapon /swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >>/etc/fstab
