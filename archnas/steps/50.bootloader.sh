grub-install --target="$ARCH-efi" --efi-directory="$ESP" --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
