# shellcheck shell=bash
# shellcheck disable=SC2006,SC2059,SC2181
#
# Modular color and style microlibrary. Individual functions or groups of functions can be imported by name when sourcing this file.
# e.g.
#   . hue.sh @import          # Import everything
#   . hue.sh @import colors   # Import only colors
#   . hue.sh @import accents  # Import the shell built-in styles, e.g. bold, underline, standout
#   . hue.sh @import b u clr  # Import bold, underline, and clear

##
# Error codes
##
#__ERR_GENERAL=64
__ERR_ARGUMENT=65
__ERR_MODULE_NOT_FOUND=66

##
# Colors
##
__hue__import_colors() {
  if [[ -t 1 ]]; then
    local c="tput setaf"
    BLACK=$($c 0); RED=$($c 1); GREEN=$($c 2); YELLOW=$($c 3); BLUE=$($c 4); MAGENTA=$($c 5); CYAN=$($c 6); WHITE=$($c 7); CLR=$(tput sgr0); NC="\\e[39m"
    black()  { printf "$BLACK$*$NC";  }; red()   { printf "$RED$*$NC";   }; green()   { printf "$GREEN$*$NC"; }
    yellow() { printf "$YELLOW$*$NC"; }; blue()  { printf "$BLUE$*$NC";  }; magenta() { printf "$MAGENTA$*$NC"; }
    cyan()   { printf "$CYAN$*$NC";   }; white() { printf "$WHITE$*$NC"; }; clr()     { printf "$CLR"; }
  else
    # shellcheck disable=SC2034
    BLACK='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' YELLOW='' WHITE='' CLR='' NC=''
    black()  { printf "$*"; }; red()   { printf "$*"; }; green()   { printf "$*"; };
    yellow() { printf "$*"; }; blue()  { printf "$*"; }; magenta() { printf "$*"; };
    cyan()   { printf "$*"; }; white() { printf "$*"; }; clr()     { :; }
  fi
}

##
# Built-in accents
##
__hue__import_u() {
  if [[ -t 1 ]]; then
    U_=$(tput smul); _U=$(tput rmul)
    u() { printf "${U_}$*${_U}"; }
  else
    U_='' _U=''
    u() { printf "$*"; }
  fi
}

__hue__import_b() {
  if [[ -t 1 ]]; then
    B_="$(tput bold)"; _B="\\033[22m"
    b() { printf "${B_}$*${_B}"; }
  else
    B_='' _B=''
    b() { printf "$*"; }
  fi
}

__hue__import_so() {
  if [[ -t 1 ]]; then
    SO_=$(tput smso) _SO=$(tput rmso)
    so() { printf "${SO_}$*${_SO}"; }
  else
    so() { printf "$*"; }
    SO_='' _SO=''
  fi
}

__hue__import_clr() {
  if [[ -t 1 ]]; then
    clr() { tput sgr0; }
  else
    clr() { :; }
  fi
}

__hue__import_accents() {
  __hue__import_u
  __hue__import_b
  __hue__import_so
  __hue__import_clr
}

##
# Additional custom styles
##
__hue__import_em() {
  if [[ -t 1 ]]; then
    EM_=$(tput bold); _EM="\\033[22m"
    em() { printf "${EM_}$*${_EM}"; }
  else
    em() { printf "$*"; }
    EM_='' _EM=''
  fi
}

__hue__import_err() {
  if [[ -t 1 ]]; then
    ERR_=$(tput setaf 1); _ERR="\\e[39m"
    err() { printf "${ERR_}$*${_ERR}"; }
  else
    err() { printf "$*"; }
    ERR_='' _ERR=''
  fi
}

__hue__import_wrn() {
  if [[ -t 1 ]]; then
    WRN_=$(tput setaf 1); _WRN="\\e[39m"
    wrn() { printf "${WRN_}$*${_WRN}"; }
  else
    wrn() { printf "$*"; }
    WRN_='' _WRN=''
  fi
}

__hue__import_success() {
  if [[ -t 1 ]]; then
    SUCCESS_="$(tput bold)$(tput setaf 2)"; _SUCCESS="\\e[39m\\033[22m"
    success() { printf "${SUCCESS_}$*${_SUCCESS}"; }
  else
    SUCCESS_='' _SUCCESS=''
    success() { printf "$*"; }
  fi
}

__hue__import_failure() {
  if [[ -t 1 ]]; then
    FAILURE_="$(tput bold)$(tput setaf 1)"; _FAILURE="\\e[39m\\033[22m"
    failure() { printf "${FAILURE_}$*${_FAILURE}"; }
  else
    FAILURE_='' _FAILURE=''
    failure() { printf "$*"; }
  fi
}

__hue__import_styles() {
  __hue__import_wrn
  __hue__import_err
  __hue__import_em
  __hue__import_success
  __hue__import_failure
}

__hue__import_all() {
  __hue__import_colors
  __hue__import_accents
  __hue__import_styles
}

fail() { echo "$1" 1>&2; exit "$2"; }

##
# Module main
##
__hue__() {
  [[ $1 != "@import" ]] && fail "ERROR: First argument must be @import" $__ERR_ARGUMENT
  shift
  (( $# == 0 )) && __hue__import_all && return
  for arg in "$@"; do
    [[ $- == *"e"* ]] && is_e=true; set +e
    "__hue__import_$arg"
    local status=$?
    [[ -n ${is_e:-} ]] && set -e
    if (( status == 127 )); then
      fail "ERROR: Module or function '$arg' not found!" $__ERR_MODULE_NOT_FOUND
    fi
  done
}

__hue__ "$@"
