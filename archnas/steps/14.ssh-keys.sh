echo "Allowing SSH for GitHub user $GITHUB_USERNAME"
mkdir -m 0700 "$USER_HOME/.ssh"
curl -sS "https://github.com/$GITHUB_USERNAME.keys" >>"$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
