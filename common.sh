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
ask() {
  local question="2"
  local options="3"
  local default="4"
  local answer

  # If ASK_AUTO_APPROVE is set, just return the default.
  if [[ -n $ASK_AUTO_APPROVE ]]; then
    read -r "$1" <<< "${!default}"
    return
  fi

  # If default is set and not empty
  if [[ -n "${!default:-}" ]]; then
    local options_string="${!options+${!options[@]// /\/} }"
    if [[ ${!options:-*} == * ]]; then
      options_string="[${!default}] "
    elif [[ $options_string != *"${!default}"* ]]; then
      echo "Default value does not appear in the options list" && return 3
    else
      # Make the default option appear in uppercase
      options_string="(${options_string/${!default}/${!default^^}})"
    fi
  fi

  while true; do
    read -rp "${!question} $options_string" answer
    answer="${answer:-${!default:-}}"
    if [[ ${!options:-*} == "*" ]]; then
      # Populate the user-passed in variable
      read -r "$1" <<< "$answer"
      return
    fi
    # Trim and collapse whitespace and convert to lowercase
    local normal_opts="$(printf %s "${!options}" | xargs echo -n | awk '{print tolower($0)}')"
    local opt_pattern='^('"${normal_opts// /|}"')$'
    if [[ $answer =~ $opt_pattern ]]; then
      read -r "$1" <<< "$answer"
      return
    else
      echo "ERROR: Invalid option, must be one of: ${normal_opts// /, }"
    fi
  done
}
