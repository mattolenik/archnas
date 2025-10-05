# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init bash)"' >>"$USER_HOME/.bashrc"
# shellcheck disable=SC2016
echo 'command -v starship &>/dev/null && eval "$(starship init zsh)"' >>"$USER_HOME/.zshrc"
