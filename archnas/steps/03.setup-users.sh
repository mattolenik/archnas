echo "Setting up user $USER_NAME"

useradd -m -G adm,log,sys,uucp,wheel -s "$(command -v zsh)" "$USER_NAME"
chpasswd <<<"$USER_NAME:$PASSWORD"

echo "Allowing SSH for GitHub user $GITHUB_USERNAME"
mkdir -m 0700 "$USER_HOME/.ssh"
curl -sS "https://github.com/$GITHUB_USERNAME.keys" >>"$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init bash)"' >>"$USER_HOME/.bashrc"
# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init zsh)"' >>"$USER_HOME/.zshrc"

chown -c -R "$USER_NAME:$USER_NAME" "$USER_HOME"
