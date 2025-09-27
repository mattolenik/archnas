rm -rf /tmp/*
# Remove leftovers from AUR builds
rm -rf "$USER_HOME/go"
passwd -d root
passwd -l root
