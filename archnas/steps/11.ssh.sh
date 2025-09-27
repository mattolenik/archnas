echo "Allowing SSH for GitHub user $1"
mkdir -m 0700 "$USER_HOME/.ssh"
curl -sS "https://github.com/$1.keys" >>"$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
