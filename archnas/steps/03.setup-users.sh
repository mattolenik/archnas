echo "Setting up user $USER_NAME"
useradd -m -G adm,log,sys,uucp,wheel -s "$(command -v zsh)" "$USER_NAME"
chpasswd <<<"$USER_NAME:$PASSWORD"
add_ssh_key_from_github "$GITHUB_USERNAME"
# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init bash)"' >>"$USER_HOME/.bashrc"
# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init zsh)"' >>"$USER_HOME/.zshrc"
chown -c -R "$USER_NAME:$USER_NAME" "$USER_HOME"
