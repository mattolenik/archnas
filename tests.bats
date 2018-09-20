#!/usr/bin/env bats
IS_TEST=true
source args.sh

options=()
positionals=()

@test "test" {
  test_args=(pos1 -a -b --test pos3 pos4)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "-a= -b= --test=pos3" ]]
  [[ ${positionals[*]} == "pos1 pos3 pos4" ]]
}

@test "single_opt" {
  test_args=(-a val)
  parse_args handle_options_consume positionals "${test_args[@]}"
  [[ ${options[*]} == "-a=val" ]]
  [[ -z ${positionals[*]} ]]
}

@test "single_opts" {
  test_args=(-a -b -c)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "-a= -b= -c=" ]]
  [[ -z ${positionals[*]} ]]
}

@test "single_opt_group" {
  test_args=(-abc)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "-a= -b= -c=" ]]
  [[ -z ${positionals[*]} ]]
}


@test "single_opt_group_with_arg" {
  test_args=(-abc valc)
  parse_args handle_options_consume positionals "${test_args[@]}"
  [[ ${options[*]} == "-a= -b= -c=valc" ]]
  [[ -z ${positionals[*]} ]]
}

@test "double_options" {
  test_args=(--alpha --beta --gamma)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "--alpha= --beta= --gamma=" ]]
  [[ -z ${positionals[*]} ]]
}

@test "double_options_with_positionals" {
  test_args=(--alpha --beta --gamma one two three)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "--alpha= --beta= --gamma=one" ]]
  [[ ${positionals[*]} == "one two three" ]]
}

@test "double_options_with_args_and_positionals" {
  test_args=(--alpha --beta=b --gamma one two three)
  parse_args handle_options positionals "${test_args[@]}"
  [[ ${options[*]} == "--alpha= --beta=b --gamma=one" ]]
  [[ ${positionals[*]} == "one two three" ]]
}

@test "double_arguments" {
  test_args=(--alpha a --beta b --gamma=c)
  parse_args handle_options_consume positionals "${test_args[@]}"
  [[ ${options[*]} == "--alpha=a --beta=b --gamma=c" ]]
  [[ -z ${positionals[*]} ]]
}

@test "doozy" {
  test_args=(-a -bcD valD --opt1 -o --arg1=val1 --arg2="val 2" --arg3="val 3" one 't wo' "th ree")
  parse_args handle_options_consume positionals "${test_args[@]}"
  [[ ${options[*]} == "-a= -b= -c= -D=valD --opt1= -o= --arg1=val1 --arg2=val 2 --arg3=val 3" ]]
  [[ ${positionals[*]} == "one t wo th ree" ]]
}

handle_options() {
  options+=(${1}${2}=${3:-})
  return 0
}

handle_options_consume() {
  options+=(${1}${2}=${3:-})
  return 1
}
