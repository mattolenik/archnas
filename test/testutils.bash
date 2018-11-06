# shellcheck shell=bash

##
# Performs an HTTP get, storing the body in the variable named by $1 and
# storing the HTTP status in $2.
# $1 - out variable to read body into, will be blank in case of curl failure
# $2 - out variable to read status into, will be 000 in case of curl failure
# $3 - URL to get
##
http_get() {
  # The status code will be printed after the body.
  local result err
  result="$(curl --insecure -sLw '\n%{http_code}\n' "$3")"
  err=$?
  # Read the body into the name of the variable passed in as $1
  read -r "$1" < <(sed '$d' <<< "$result")
  read -r "$2" < <(tail -n1 <<< "$result")
  (( err != 0 )) && return $err
}

fail() {
  echo "$@" && return 1
}
