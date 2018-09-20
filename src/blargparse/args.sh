#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x

##
# Parses command-line arguments
# Parameters:
# $1  name of the function to handle options
# $2  name of the variable to contain array of positionals
# ..  remaining are the arguments to parse
parse_args() {
  local _handle_option=$1 _positionals_var_name=$2
  shift 2
  local _quot_word="\"(.*)\"|'(.*)'|(.*)"
  # Matches single char opts e.g. -a or groups of opts e.g. -abx
  local _single_dash_option="^-([^[:blank:]]+)$"
  # Matches a double dash option that may or may not have a value
  local _double_dash_option="^--([^[:blank:]=]+)($|=)($_quot_word)?"
  local _name _next_arg _arg _value
  local _args=("$@") __i=0 __k=0
  declare -a -g "$_positionals_var_name"
  while (( __i < $# )); do
    _arg="${_args[$__i]}"
    _next_arg="${_args[$__i+1]:-}"
    if [[ $_arg =~ $_double_dash_option ]]; then
      # This if block handles the case of double-dash options with an equals
      # sign, e.g. --output=filename. It handles quotes around the option.
      _name="${BASH_REMATCH[1]}"
      if [[ -n ${BASH_REMATCH[2]} ]]; then
        # The value of the quoted/unquoted string ends up in one of three groups
        _value="${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
        $_handle_option -- "$_name" "$_value" || true
      else
        # If the next option isn't another option (doesn't begin with
        # a dash), treat it as the value for the current option.
        if (( __i + 1 == $# )) || [[ $_next_arg == -* ]]; then
          $_handle_option -- "$_name" || true
        else
          $_handle_option -- "$_name" "${_args[@]:$__i+1:1}" || __i=$((__i + $?))
        fi
      fi
    elif [[ "$_arg" =~ $_single_dash_option ]]; then
      # This elif block handles single-letter opts and groups of opts,
      # e.g. '-o "filename"' or '-vfd' which becomes -v -f -d
      _name="${BASH_REMATCH[1]}"
      # Groups of options can't have values, except for the last one.
      for (( __k=0; __k < ${#_name} - 1; __k++ )); do
        $_handle_option - "${_name:$__k:1}" || true
      done
      # Don't pass a value if on the last arg or if the next arg is an option
      if (( __i + 1 == $# )) || [[ $_next_arg == -* ]]; then
        $_handle_option - "${_name: -1}" || true
      else
        $_handle_option - "${_name: -1}" "${_args[@]:$__i+1:1}" || __i=$((__i + $?))
      fi
    else
      eval "$_positionals_var_name+=(\"$_arg\")"
    fi
    __i=$((__i + 1))
  done
}
