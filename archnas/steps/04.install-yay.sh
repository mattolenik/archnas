(
  cd "$(mktemp -d)"
  curl -sSL "$(github_get_latest_release Jguer/yay | grep "$ARCH")" | tar xz --strip-components=1
  mv -f yay /usr/bin/
  mv -f yay.8 /usr/share/man/
  mkdir -p /etc/bashrc.d /etc/zshrc.d
  mv -f bash /etc/bashrc.d/yay
  mv -f zsh /etc/zshrc.d/yay
)