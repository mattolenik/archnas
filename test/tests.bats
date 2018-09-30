#!/usr/bin/env bats
source testutils.sh

@test "check_plex_web" {
  http_get body status "http://127.0.0.1:32400"
  (( status / 100 == 2 )) || echo "Invalid HTTP status $status" && return 1
}
