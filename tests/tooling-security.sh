#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tooling-security.XXXXXX")"
OUT="$TMP_DIR/out"
FAILURES=0

trap 'rm -rf "$TMP_DIR"' EXIT

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

run_test() {
  local name="$1"
  shift

  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

make_fixture() {
  local fixture="$1"

  mkdir -p \
    "$fixture/.claude/scripts" \
    "$fixture/docker/local" \
    "$fixture/source/src" \
    "$fixture/source/tests/Unit"

  cp "$ROOT/payload/Makefile.ai" "$fixture/Makefile.ai"
  cp "$ROOT/payload/.claude/scripts/ai-docker.sh" "$fixture/.claude/scripts/ai-docker.sh"
  chmod +x "$fixture/.claude/scripts/ai-docker.sh"

  printf '<?php\n' > "$fixture/source/src/Foo.php"
  printf '<?php\n' > "$fixture/source/tests/Unit/FooTest.php"
}

make_fake_docker() {
  local bin_dir="$1"
  local log_file="$2"

  mkdir -p "$bin_dir"
  cat > "$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
{
  printf 'CALL\n'
  printf '%s\n' "$@"
} >> "${FAKE_DOCKER_LOG:?}"
exit 0
SH
  chmod +x "$bin_dir/docker"
  : > "$log_file"
}

run_make_env() {
  local fixture="$1"
  local env_name="$2"
  local env_value="$3"
  shift 3

  (
    cd "$fixture"
    env \
      "PATH=$TMP_DIR/bin:$PATH" \
      "FAKE_DOCKER_LOG=$TMP_DIR/docker.log" \
      "$env_name=$env_value" \
      make -f Makefile.ai "$@"
  )
}

rejects_test_payload() {
  local payload="$1"
  local marker="$2"
  local fixture="$TMP_DIR/project"
  local status

  set +e
  run_make_env "$fixture" AI_TEST "$payload" ai-test >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -ne 0 ] && [ ! -e "$marker" ]
}

test_valid_lint_uses_container_path() {
  local fixture="$TMP_DIR/project"

  : > "$TMP_DIR/docker.log"
  run_make_env "$fixture" AI_FILE source/src/Foo.php ai-lint >/dev/null

  grep -Fxq 'php' "$TMP_DIR/docker.log" &&
    grep -Fxq -- '-l' "$TMP_DIR/docker.log" &&
    grep -Fxq 'src/Foo.php' "$TMP_DIR/docker.log"
}

test_rejects_shell_operators_in_test_path() {
  local marker="$TMP_DIR/injected-and"

  rejects_test_payload "tests/Unit/FooTest.php && touch $marker" "$marker"
}

test_rejects_semicolon_in_test_path() {
  local marker="$TMP_DIR/injected-semicolon"

  rejects_test_payload "tests/Unit/FooTest.php; touch $marker" "$marker"
}

test_rejects_pipe_and_parens_in_test_path() {
  local marker="$TMP_DIR/injected-pipe"

  rejects_test_payload "tests/Unit/FooTest.php | (touch $marker)" "$marker"
}

test_rejects_command_substitution_in_test_path() {
  local marker="$TMP_DIR/injected-sub"
  local payload="tests/Unit/FooTest.php\$(touch $marker)"

  rejects_test_payload "$payload" "$marker"
}

test_rejects_make_shell_function_in_test_path() {
  local marker="$TMP_DIR/injected-make-shell"
  local payload="tests/Unit/FooTest.php\$(shell touch $marker)"

  rejects_test_payload "$payload" "$marker"
}

test_rejects_backticks_in_test_path() {
  local marker="$TMP_DIR/injected-backtick"
  local payload="tests/Unit/FooTest.php\`touch $marker\`"

  rejects_test_payload "$payload" "$marker"
}

test_rejects_newline_in_test_path() {
  local marker="$TMP_DIR/injected-newline"
  local payload

  payload=$'tests/Unit/FooTest.php\n touch '"$marker"
  rejects_test_payload "$payload" "$marker"
}

test_rejects_leading_option_in_test_path() {
  rejects_test_payload "--filter=Foo" "$TMP_DIR/unused-leading-option"
}

test_rejects_path_traversal_in_test_path() {
  rejects_test_payload "tests/Unit/../FooTest.php" "$TMP_DIR/unused-traversal"
}

test_rejects_symlink_test_path() {
  local fixture="$TMP_DIR/project"
  local outside="$TMP_DIR/OutsideTest.php"
  local status

  printf '<?php\n' > "$outside"
  ln -s "$outside" "$fixture/source/tests/Unit/LinkTest.php"

  set +e
  run_make_env "$fixture" AI_TEST tests/Unit/LinkTest.php ai-test >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -ne 0 ]
}

test_rejects_route_path_injection() {
  local fixture="$TMP_DIR/project"
  local marker="$TMP_DIR/injected-route"
  local status

  set +e
  run_make_env "$fixture" AI_ROUTE_PATH "api/v1 && touch $marker" ai-route-list >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -ne 0 ] && [ ! -e "$marker" ]
}

test_settings_has_no_make_wildcard_auto_allow() {
  ! jq -r '.permissions.allow[]' "$ROOT/payload/.claude/settings.json" |
    grep -Eq '^Bash\(make -f Makefile\.ai .*\*\)$'
}

test_block_host_tools_rejects_make_cli_vars() {
  local status

  set +e
  printf '%s\n' '{"tool_input":{"command":"make -f Makefile.ai ai-test TEST=tests/Unit/FooTest.php"}}' |
    bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Không truyền FILE/TEST' "$OUT"
}

test_block_host_tools_allows_env_prefix() {
  local status

  set +e
  printf '%s\n' '{"tool_input":{"command":"AI_TEST=tests/Unit/FooTest.php make -f Makefile.ai ai-test"}}' |
    bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 0 ]
}

test_sync_rejects_invalid_mode_before_apply() {
  local src="$TMP_DIR/source-project"
  local status

  mkdir -p "$src/source"
  printf '{}\n' > "$src/source/composer.json"

  set +e
  "$ROOT/sync-from-project.sh" "$src" --aply >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Option không hợp lệ' "$OUT"
}

test_sync_dry_run_includes_claude_scripts() {
  local src="$TMP_DIR/sync-source"

  mkdir -p "$src/source" "$src/.claude/scripts"
  printf '{}\n' > "$src/source/composer.json"

  "$ROOT/sync-from-project.sh" "$src" --dry-run >"$OUT" 2>&1

  grep -q '\.claude/scripts' "$OUT"
}

test_strict_related_tests_fail_closed_without_makefile() {
  local project="$TMP_DIR/hook-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php\n' > "$project/source/tests/Unit/FooTest.php"
  git -C "$project" init -q

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'UNVERIFIED' "$OUT"
}

test_install_creates_precise_backup_and_excludes_bak_suffixes() {
  local target="$TMP_DIR/install-target"
  local home="$TMP_DIR/home"
  local exclude

  mkdir -p "$target" "$home"
  git -C "$target" init -q
  printf 'old\n' > "$target/CLAUDE.md"

  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1

  exclude="$(git -C "$target" rev-parse --git-path info/exclude)"
  compgen -G "$target/CLAUDE.md.bak.*" >/dev/null &&
    grep -Fxq '*.bak.*' "$target/$exclude" &&
    [ -x "$target/.claude/scripts/ai-docker.sh" ] &&
    grep -q 'CLAUDE.md.bak.' "$OUT"
}

fixture="$TMP_DIR/project"
make_fixture "$fixture"
make_fake_docker "$TMP_DIR/bin" "$TMP_DIR/docker.log"

run_test "valid lint passes container-relative path" test_valid_lint_uses_container_path
run_test "ai-test rejects && injection" test_rejects_shell_operators_in_test_path
run_test "ai-test rejects semicolon injection" test_rejects_semicolon_in_test_path
run_test "ai-test rejects pipe and paren injection" test_rejects_pipe_and_parens_in_test_path
run_test "ai-test rejects command substitution" test_rejects_command_substitution_in_test_path
run_test "ai-test rejects make shell function" test_rejects_make_shell_function_in_test_path
run_test "ai-test rejects backticks" test_rejects_backticks_in_test_path
run_test "ai-test rejects newline injection" test_rejects_newline_in_test_path
run_test "ai-test rejects leading options" test_rejects_leading_option_in_test_path
run_test "ai-test rejects path traversal" test_rejects_path_traversal_in_test_path
run_test "ai-test rejects symlink traversal" test_rejects_symlink_test_path
run_test "ai-route-list rejects route path injection" test_rejects_route_path_injection
run_test "settings has no Makefile wildcard auto-allow" test_settings_has_no_make_wildcard_auto_allow
run_test "block-host-tools rejects old Makefile variables" test_block_host_tools_rejects_make_cli_vars
run_test "block-host-tools allows env-prefix Makefile commands" test_block_host_tools_allows_env_prefix
run_test "sync rejects invalid mode" test_sync_rejects_invalid_mode_before_apply
run_test "sync dry-run includes .claude/scripts" test_sync_dry_run_includes_claude_scripts
run_test "strict test hook fails closed without Makefile" test_strict_related_tests_fail_closed_without_makefile
run_test "install backup/exclude/scripts are safe" test_install_creates_precise_backup_and_excludes_bak_suffixes

if [ "$FAILURES" -ne 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
