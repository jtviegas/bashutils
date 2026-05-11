#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "$BATS_TEST_DIRNAME/../bashutils-template.sh" "$TEST_DIR/bashutils-template.sh"
  cp "$BATS_TEST_DIRNAME/../.bashutils" "$TEST_DIR/.bashutils"
  chmod +x "$TEST_DIR/bashutils-template.sh"
  touch "$TEST_DIR/.bashutils.last_check"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "shows usage with no arguments" {
  run "$TEST_DIR/bashutils-template.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
  [[ "$output" == *"hello_world"* ]]
}

@test "runs hello_world command" {
  run "$TEST_DIR/bashutils-template.sh" hello_world
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello world"* ]]
  [[ "$output" == *"[hello_world|out] => 0"* ]]
}
