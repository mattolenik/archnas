echo "$TIMEZONE.UTF-8 UTF-8" >/etc/locale.gen
echo "LANG=$TIMEZONE.UTF-8" >/etc/locale.conf
locale-gen
