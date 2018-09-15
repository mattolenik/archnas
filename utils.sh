# shellcheck shell=bash
bail() {
  echo "$@" && exit 1
}

red="$(tput setaf 1)"
green="$(tput setaf 2)"
blue="$(tput setaf 4)"
bold="$(tput bold)"
clr="$(tput sgr0)"
green() { printf %s "${green}${bold}$*${clr}"; }
red() { printf %s "${red}${bold}$*${clr}"; }
blue() { printf %s "${blue}${bold}$*${clr}"; }
bold() { printf %s "${bold}$*${clr}"; }

# Colored banner, first arg should be character(s) from tput
cbanner() {
  printf %s $1
  shift
  figlet "$*"
  printf %s $clr
}
