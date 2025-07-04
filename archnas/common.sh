# shellcheck shell=bash
##
# Prompt the user and wait for an answer. An optional default value
# can be returned when the user skips the question by pressing ENTER.
##
# $1 - Output variable that will contain the result
# $2 - Question string, without indicating options yourself. For example,
#      don't pass in "Question? (y/n)", just "Question?". The options will be
#      added automatically.
# $3 - Options for the prompt, as a space-separated list. Use * for freeform
#      input. Options are automatically lowercase only.
# $4 - Default value, optional
##

[[ -n "${__COMMON_SH__:-}" ]] && return || __COMMON_SH__=1
#IMPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

ask() {
  if [[ $1 == "export" ]]; then
    local should_export=1
    shift
  fi
  if [[ $1 == "-s" ]]; then
    local silent=1
    shift
  fi
  local _question="2"
  local _options="3"
  local _default="4"
  local _answer

  # If AUTO_APPROVE is set, just return the default.
  if [[ -n ${AUTO_APPROVE:-} ]]; then
    read -r "$1" <<<"${!_default:-}"
    return
  fi

  # If default is set and not empty
  if [[ -n "${!_default:-}" ]]; then
    local _options_string="${!_options+${!_options// /\/} }"
    if [[ ${!_options:-*} == * ]]; then
      _options_string="[${!_default}] "
    elif [[ $_options_string != *"${!_default}"* ]]; then
      echo "Default value does not appear in the options list" && return 3
    else
      # Make the default option appear in uppercase
      _options_string="(${_options_string/${!_default}/${!_default^^}})"
    fi
  fi

  while true; do
    local flags=-rp
    if [[ -n ${silent:-} ]]; then
      flags=-srp
    fi
    read $flags "${!_question} ${_options_string:-}" _answer
    _answer="${_answer:-${!_default:-}}"
    if [[ ${!_options:-*} == "*" ]]; then
      # Populate the user-passed in variable
      read -r "$1" <<<"$_answer"
      if [[ -n ${should_export:-} ]]; then
        export "$1"
      fi
      return
    fi
    # Trim and collapse whitespace and convert to lowercase
    local normal_opts="$(printf %s "${!_options}" | xargs echo -n | awk '{print tolower($0)}')"
    local opt_pattern='^('"${normal_opts// /|}"')$'
    if [[ $_answer =~ $opt_pattern ]]; then
      read -r $1 <<<"$_answer"
      if [[ -n ${should_export:-} ]]; then
        export "$1"
      fi
      return
    else
      echo "ERROR: Invalid option, must be one of: ${normal_opts// /, }"
    fi
  done
}

fail() {
  echo "$*" && exit 1
}

# Repeat a string n times
# $1 - string to repeat
# $2 - number of times to repeat
str_repeat() {
  local i=0
  while ((i++ < $2)); do
    printf %s "$1"
  done
}

# Create a banner in a box
# $1   - message to print inside the box
# $2   - padding, default of 3 (optional)
# $2/3 - color/style characters (optional)
#        If padding is passed as $2, then color becomes $3. If padding is
#        omitted, color becomes $2.
boxbanner() {
  local msg bar_str color_str padding_len padding_str
  msg="$1"
  if [[ $2 =~ ^[0-9]+$ ]]; then
    padding_len="$2"
    color_str="${3:-}"
  else
    padding_len=2
    color_str="${2:-}"
  fi
  padding_str="$(str_repeat ' ' "$padding_len")"
  bar_str="$(str_repeat '═' $((padding_len * 2 + ${#msg})))"
  printf '%s' "${color_str:-}"
  printf '╔%s╗\n' "$bar_str"
  printf '║%s║\n' "${padding_str}${msg}${padding_str}"
  printf '╚%s╝\n' "$bar_str"
  [[ -n ${color_str:-} ]] && tput sgr0 || true
}

ask_password_confirm() {
  if [[ $1 == "export" ]]; then
    local should_export=1
    shift
  fi
  local var="$1"
  shift
  local pw1 pw2
  while true; do
    ask -s pw1 "$@"
    printf '\n[Confirm] '
    ask -s pw2 "$@"
    if [[ $pw1 == "$pw2" ]]; then
      break
    fi
    echo "Passwords do not match, please try again"
    echo
  done
  read -r "$var" <<<"$pw1"
  if [[ -n ${should_export:-} ]]; then
    export "$var"
  fi
  echo
}

github_get_latest_release() {
  curl -sS "https://api.github.com/repos/$1/releases/latest" | jq .assets[].browser_download_url -r
}

github_get_latest_tag() {
  curl -sS "https://api.github.com/repos/$1/releases/latest" | jq .tag_name -r
}
