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
