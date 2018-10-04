#!/usr/bin/env bats
load testutils

@test "check_plex_web" {
  http_get body status_code "http://127.0.0.1:32400"
  echo "$body"
  (( status / 100 == 2 )) || echo "Invalid HTTP status $status_code" && return 1
}
