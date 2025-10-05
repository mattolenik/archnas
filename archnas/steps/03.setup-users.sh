echo "Setting up user $USER_NAME"

useradd -m -G adm,log,sys,uucp,wheel -s "$(command -v zsh)" "$USER_NAME"
chpasswd <<<"$USER_NAME:$PASSWORD"

chown -c -R "$USER_NAME:$USER_NAME" "$USER_HOME"
