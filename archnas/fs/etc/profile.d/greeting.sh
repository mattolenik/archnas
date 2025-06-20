source /etc/environment

cat << EOF
Welcome to ArchNAS

If using Frigate, an RTSP password must be set otherwise Frigate will not start. Be sure to run this:

    echo your_rtsp_password | sudo systemd-creds encrypt - $CREDENTIALS_DIRECTORY/frigate_rtsp_password


After all your setup is done, remove this notice by running:

    sudo rm /etc/profile.d/greeting

EOF

services="$(systemctl list-units --state=failed --no-pager -q)"
if [ -n "$services" ]; then
  echo 'The following services have failed. To diagnose them, run `journalctl -u <service>`, e.g. `journalctl -u frigate`'
  printf '\n%s\n' "$services"
fi

