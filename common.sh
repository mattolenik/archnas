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
# $4 - Default value, or empty string if unset
##
ask() {
  local out_var="$1"
  local question="$2"
  # Trim and reduce whitespace and replace spaces with pipes
  local options="${3:-*}"
  local default="${4:-}"
  local confirm
  local result
  get_named_arg confirm "confirm" '' "${@:5}"
  echo $confirm

  # A nicely formatted option string in the style of: (yes/no/CANCEL)
  # The default option, if any, will be in uppercase.
  local options_string="${options+(${options[@]// /\/}) }"
  if [[ -n "$default" ]] && [[ $options_string != *"$default"* ]]; then
    echo "Default value does not appear in the options list" && return 3
    # Make the default option appear in uppercase
    options_string="${options_string/$default/${default^^}}"
  fi
  while true; do
    read -rp "${question} $options_string" result
    if [[ -z $result ]] && [[ -z $default ]]; then
      return
    fi
    if [[ $options == "*" ]]; then
      # Populate the user-passed in variable
      read -r "$out_var" <<< "$result"
      return
    else
      # Trim and collapse whitespace and convert to lowercase
      options="$(printf %s "$options" | xargs echo -n | awk '{print tolower($0)}')"
      if [[ $result =~ ^(${options// /|})$ ]]; then
	read -r "$out_var" <<< "$result"
	return
      else
	echo "ERROR: Invalid option, must be one of: ${options// /,}"
      fi
    fi
  done
}

get_named_arg() {
  local out_var="$1"
  local key="$2"
  local default="${3:-}"
  shift 3
  for pair in "$@"; do
    if [[ $pair =~ ^@([^=]+)=([^=]*)$ ]] && [[ ${BASH_REMATCH[1]} == "$key" ]]; then
      read -r "$out_var" <<< "${BASH_REMATCH[2]}" && return
    fi
  done
  read -r "$out_var" <<< "$default"
}
