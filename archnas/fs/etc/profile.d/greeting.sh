cat << EOF
Welcome to ArchNAS

If using Frigate, remember to set RTSP passwords, otherwise Frigate will not start:

    echo your_rtsp_password | sudo systemd-creds encrypt - $CREDENTIALS_DIRECTORY/frigate/rtsp/cam-fd


After all your setup is done, remove this notice by running:

    sudo rm /etc/profile.d/greeting

EOF

services="$(systemctl list-units --state=failed --no-pager -q)"
if [ -n "$services" ]; then
  echo 'The following services have failed. To diagnose them, run `journalctl -u <service>`, e.g. `journalctl -u frigate`'
  printf '\n%s\n' "$services"
fi

