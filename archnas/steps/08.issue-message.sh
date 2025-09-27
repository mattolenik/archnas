rm -rf /etc/issue.d
mkdir /etc/issue.d
cat <<EOF >>/etc/issue.d/service-info.issue
Cockpit: https://$HOST_NAME.$DOMAIN:9090
Frigate: http://$HOST_NAME.$DOMAIN:8971
Webmin:  https://$HOST_NAME.$DOMAIN:10000
EOF
