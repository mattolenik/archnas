#!/usr/bin/env bats
load testutils

@test "check_plex_web" {
  http_get body status_code "http://127.0.0.1:32400/web"
  (( status / 100 == 2 )) || fail "Invalid HTTP status $status_code"
  local title=$(pup 'title text{}' <<< "$body")
  [[ $title == "Plex" ]] || fail "Unexpected page title '$title' found"
}
