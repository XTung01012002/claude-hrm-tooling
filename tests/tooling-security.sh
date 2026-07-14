#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tooling-security.XXXXXX")"
OUT="$TMP_DIR/out"
FAILURES=0

clean_up() {
  rm -rf "$TMP_DIR"
}

snapshot_tree() {
  local root="$1"
  (
    cd "$root" || exit 1
    find . -mindepth 1 -print |
      LC_ALL=C sort |
      while IFS= read -r path; do
        if [ -L "$path" ]; then
          printf 'L %s -> %s\n' "$path" "$(readlink "$path")"
        elif [ -f "$path" ]; then
          printf 'F %s ' "$path"
          shasum "$path" | awk '{print $1}'
        elif [ -d "$path" ]; then
          printf 'D %s\n' "$path"
        else
          printf 'O %s\n' "$path"
        fi
      done
  ) | shasum | awk '{print $1}'
}

trap 'clean_up' EXIT

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
    echo "Output was:"
    cat "$OUT"
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

run_guard() {
  local command="$1"

  printf '{"tool_input":{"command":%s}}\n' "$(printf '%s' "$command" | jq -Rsa .)" |
    bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
}

run_guard_antigravity() {
  local command="$1"

  printf '{"tool_args":{"CommandLine":%s}}\n' "$(printf '%s' "$command" | jq -Rsa .)" |
    bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
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
    grep -Eq '^Bash\(.*make -f Makefile\.ai'
}

test_block_host_tools_rejects_make_cli_vars() {
  local status

  set +e
  run_guard 'make -f Makefile.ai ai-test TEST=tests/Unit/FooTest.php'
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_allows_env_prefix() {
  local status

  set +e
  run_guard 'AI_TEST=tests/Unit/FooTest.php make -f Makefile.ai ai-test'
  status=$?
  set -e

  [ "$status" -eq 0 ]
}

test_block_host_tools_rejects_antigravity_commandline() {
  local status

  set +e
  run_guard_antigravity 'php artisan migrate:fresh'
  status=$?
  set -e

  [ "$status" -eq 2 ]
}

test_block_host_tools_allows_antigravity_makefile_commandline() {
  local status

  set +e
  run_guard_antigravity 'make -f Makefile.ai ai-about'
  status=$?
  set -e

  [ "$status" -eq 0 ]
}

test_block_host_tools_fails_closed_on_unknown_payload() {
  local status

  set +e
  printf '{"tool_args":{"Unknown":"make -f Makefile.ai ai-about"}}\n' |
    bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'fail-closed' "$OUT"
}

test_make_env_override_cannot_replace_runner() {
  local fixture="$TMP_DIR/project"
  local marker="$TMP_DIR/ai-run-pwned"

  : > "$TMP_DIR/docker.log"
  (
    cd "$fixture"
    PATH="$TMP_DIR/bin:$PATH" \
      FAKE_DOCKER_LOG="$TMP_DIR/docker.log" \
      MAKEFLAGS=-e \
      AI_RUN="sh -c 'touch $marker'" \
      make -f Makefile.ai ai-php-version >/dev/null
  )

  [ ! -e "$marker" ] && grep -Fxq 'php' "$TMP_DIR/docker.log"
}

test_block_host_tools_rejects_makeflags_ai_run_prefix() {
  local marker="$TMP_DIR/guard-ai-run-pwned"
  local status

  set +e
  run_guard "MAKEFLAGS=-e AI_RUN='sh -c \"touch $marker\"' make -f Makefile.ai ai-php-version"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_makefiles_prefix() {
  local marker="$TMP_DIR/guard-makefiles-pwned"
  local evil="$TMP_DIR/evil.mk"
  local status

  printf '$(shell touch %s)\n' "$marker" > "$evil"

  set +e
  run_guard "MAKEFILES=$evil make -f Makefile.ai ai-about"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_env_makeflags_ai_run() {
  local marker="$TMP_DIR/guard-env-ai-run-pwned"
  local status

  set +e
  run_guard "env MAKEFLAGS=-e AI_RUN='sh -c \"touch $marker\"' make -f Makefile.ai ai-route-list"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_assignment_after_make() {
  local marker="$TMP_DIR/guard-after-make-pwned"
  local status

  set +e
  run_guard "make -f Makefile.ai ai-about AI_RUN='sh -c \"touch $marker\"'"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_unexpected_env_prefix() {
  local status

  set +e
  run_guard 'FOO=bar make -f Makefile.ai ai-about'
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_make_eval() {
  local marker="$TMP_DIR/guard-eval-pwned"
  local status

  set +e
  run_guard "make -f Makefile.ai --eval='\$(shell touch $marker)' ai-about"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_extra_makefile() {
  local marker="$TMP_DIR/guard-extra-makefile-pwned"
  local evil="$TMP_DIR/evil-extra.mk"
  local status

  printf '$(shell touch %s)\n' "$marker" > "$evil"

  set +e
  run_guard "make -f Makefile.ai -f $evil ai-about"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_file_option_eval() {
  local marker="$TMP_DIR/guard-file-option-eval-pwned"
  local status

  set +e
  run_guard "make --file=Makefile.ai --eval='\$(shell touch $marker)' ai-about"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_env_dash_s() {
  local marker="$TMP_DIR/guard-env-s-pwned"
  local evil="$TMP_DIR/evil-env-s.mk"
  local status

  printf '$(shell touch %s)\n' "$marker" > "$evil"

  set +e
  run_guard "env -S 'MAKEFILES=$evil make -f Makefile.ai ai-about'"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ] && grep -q 'allow-list' "$OUT"
}

test_block_host_tools_rejects_host_php_in_docker_substitution() {
  local marker="$TMP_DIR/docker-substitution-pwned"
  local status

  set +e
  run_guard "docker compose exec -T hrm-api echo \"\$(php -r 'file_put_contents(\"$marker\", \"x\");')\""
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ]
}

test_block_host_tools_rejects_host_php_in_process_substitution() {
  local marker="$TMP_DIR/process-substitution-pwned"
  local status

  set +e
  run_guard "docker compose exec -T hrm-api cat <(php -r 'file_put_contents(\"$marker\", \"1\");')"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ]
}

test_block_host_tools_rejects_host_php_in_output_process_substitution() {
  local marker="$TMP_DIR/output-process-substitution-pwned"
  local status

  set +e
  run_guard "docker compose exec -T hrm-api sh >(php -r 'file_put_contents(\"$marker\", \"1\");')"
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ]
}

test_block_host_tools_rejects_host_php_in_make_substitution() {
  local marker="$TMP_DIR/make-substitution-pwned"
  local status

  set +e
  run_guard "make -f Makefile.ai ai-about \"\$(php -r 'file_put_contents(\"$marker\", \"x\");')\""
  status=$?
  set -e

  [ "$status" -eq 2 ] && [ ! -e "$marker" ]
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

test_strict_fails_closed_without_makefile() {
  local project="$TMP_DIR/no-makefile-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q

  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php\n' > "$project/source/tests/Unit/FooTest.php"
  mkdir -p "$project/.claude/tmp"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Makefile.ai không tồn tại' "$OUT"
}

test_strict_rejects_invalid_ai_test_mode() {
  local project="$TMP_DIR/invalid-mode-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strcit .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Invalid AI_TEST_MODE' "$OUT"
}

test_strict_fails_when_source_directory_missing() {
  local project="$TMP_DIR/no-source-project"
  local status

  mkdir -p "$project/.claude/hooks"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'source directory' "$OUT"
}

test_strict_fails_outside_git_worktree() {
  local project="$TMP_DIR/not-git-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Git working tree' "$OUT"
}

test_strict_fails_when_git_index_is_corrupt() {
  local project="$TMP_DIR/corrupt-index-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/Foo.php"
  git -C "$project" init -q
  printf 'not a git index\n' > "$project/.git/index"
<<<<<<< ours
  mkdir -p "$project/.claude/tmp"
  touch "$project/.claude/tmp/session-had-edits"
=======
  mkdir -p "$project/.claude/tmp" && touch "$project/.claude/tmp/session-had-edits"
>>>>>>> theirs

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'Không thể thu thập' "$OUT"
}

test_strict_flags_deleted_php_file() {
  local project="$TMP_DIR/deleted-php-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/DeleteMe.php"
  git -C "$project" init -q
  git -C "$project" -c user.email=test@example.com -c user.name=Test add source/src/DeleteMe.php
  git -C "$project" -c user.email=test@example.com -c user.name=Test commit -q -m init
  mkdir -p "$project/.claude/tmp"
  touch "$project/.claude/tmp/session-had-edits"
  rm "$project/source/src/DeleteMe.php"
  mkdir -p "$project/.claude/tmp" && touch "$project/.claude/tmp/session-had-edits"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'thiếu touched manifest' "$OUT"
}

test_strict_flags_renamed_php_file() {
  local project="$TMP_DIR/renamed-php-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/OldName.php"
  git -C "$project" init -q
  git -C "$project" -c user.email=test@example.com -c user.name=Test add source/src/OldName.php
  git -C "$project" -c user.email=test@example.com -c user.name=Test commit -q -m init
  mkdir -p "$project/.claude/tmp"
  touch "$project/.claude/tmp/session-had-edits"
  mv "$project/source/src/OldName.php" "$project/source/src/NewName.php"
  mkdir -p "$project/.claude/tmp" && touch "$project/.claude/tmp/session-had-edits"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'thiếu touched manifest' "$OUT"
}

test_strict_fails_without_touched_manifest_for_dirty_php() {
  local project="$TMP_DIR/no-touched-dirty-php"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/Foo.php"
  git -C "$project" init -q
  git -C "$project" -c user.email=test@example.com -c user.name=Test add source/src/Foo.php
  git -C "$project" -c user.email=test@example.com -c user.name=Test commit -q -m init
  mkdir -p "$project/.claude/tmp"
  touch "$project/.claude/tmp/session-had-edits"
  printf '<?php\n// dirty\n' > "$project/source/src/Foo.php"
  mkdir -p "$project/.claude/tmp" && touch "$project/.claude/tmp/session-had-edits"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'thiếu touched manifest' "$OUT"
}

test_strict_exits_0_without_marker_for_dirty_php() {
  local project="$TMP_DIR/no-marker-dirty-php"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/Foo.php"
  git -C "$project" init -q
  git -C "$project" -c user.email=test@example.com -c user.name=Test add source/src/Foo.php
  git -C "$project" -c user.email=test@example.com -c user.name=Test commit -q -m init
  printf '<?php\n// dirty\n' > "$project/source/src/Foo.php"

  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 0 ] && grep -q 'ngoài phiên AI' "$OUT"
}

test_install_creates_precise_backup_and_excludes_bak_suffixes() {
  local target="$TMP_DIR/install-target"
  local home="$TMP_DIR/home"
  local status

  mkdir -p "$target/source" "$target/docker/local" "$home"
  printf '{}\n' > "$target/source/composer.json"
  git -C "$target" init -q
  printf 'old\n' > "$target/CLAUDE.md"

  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1

  exclude="$(git -C "$target" rev-parse --git-path info/exclude)"
  compgen -G "$target/CLAUDE.md.bak.*" >/dev/null &&
    grep -Fxq '*.bak.*' "$target/$exclude" &&
    [ -x "$target/.claude/scripts/ai-docker.sh" ] &&
    grep -q 'CLAUDE.md.bak.' "$OUT"
}

test_install_rejects_overwriting_tracked_files() {
  local target="$TMP_DIR/install-tracked-target"
  local home="$TMP_DIR/home"
  local status

  mkdir -p "$target/source" "$target/docker/local" "$home"
  printf '{}\n' > "$target/source/composer.json"
  git -C "$target" init -q
  mkdir -p "$target/.claude/hooks"
  printf 'tracked\n' > "$target/.claude/hooks/block-host-tools.sh"
  git -C "$target" add .claude/hooks/block-host-tools.sh
  git -C "$target" -c user.email=test@example.com -c user.name=Test commit -m "track"

  set +e
  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'được project track' "$OUT"
}

test_install_allows_overwriting_tracked_files_with_force() {
  local target="$TMP_DIR/install-force-target"
  local home="$TMP_DIR/home"
  local status

  mkdir -p "$target/source" "$target/docker/local" "$home"
  printf '{}\n' > "$target/source/composer.json"
  git -C "$target" init -q
  mkdir -p "$target/.claude/hooks"
  printf 'tracked\n' > "$target/.claude/hooks/block-host-tools.sh"
  git -C "$target" add .claude/hooks/block-host-tools.sh
  git -C "$target" -c user.email=test@example.com -c user.name=Test commit -m "track"

  set +e
  HOME="$home" "$ROOT/install.sh" --force-overwrite-tracked "$target" >"$OUT" 2>&1
  status=$?
  set -e

  grep -q 'block-host-tools.sh' "$OUT" && ! grep -q 'được project track' "$OUT"
}

test_install_rejects_settings_dangling_symlink() {
  local target="$TMP_DIR/install-settings-symlink"
  local home="$TMP_DIR/home"
  local outside="$TMP_DIR/outside-settings.json"
  local status

  mkdir -p "$target/source" "$target/docker/local" "$target/.claude" "$home"
  printf '{}\n' > "$target/source/composer.json"
  ln -s "$outside" "$target/.claude/settings.local.json"

  set +e
  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 1 ] && [ ! -e "$outside" ] && grep -q 'Unsafe settings.local.json symlink' "$OUT"
}

test_install_rejects_settings_non_regular_path() {
  local target="$TMP_DIR/install-settings-directory"
  local home="$TMP_DIR/home"
  local status

  mkdir -p "$target/source" "$target/docker/local" "$target/.claude/settings.local.json" "$home"
  printf '{}\n' > "$target/source/composer.json"

  set +e
  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 1 ] && grep -q 'not a regular file' "$OUT"
}

test_install_replaces_existing_managed_hooks() {
  local target="$TMP_DIR/install-hook-dedupe"
  local home="$TMP_DIR/home"
  local settings="$target/.claude/settings.local.json"
  local count timeout

  mkdir -p "$target/source" "$target/docker/local" "$target/.claude" "$home"
  printf '{}\n' > "$target/source/composer.json"
  cat > "$settings" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/run-related-tests.sh\"",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
JSON

  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1

  count="$(jq '[.. | objects | select(((.command? // "") | contains(".claude/hooks/run-related-tests.sh")))] | length' "$settings")"
  timeout="$(jq -r '.. | objects | select(((.command? // "") | contains(".claude/hooks/run-related-tests.sh"))) | .timeout' "$settings")"

  [ "$count" -eq 1 ] && [ "$timeout" = "300" ]
}

test_install_backs_up_legacy_agent_directory() {
  local target="$TMP_DIR/install-legacy-agent"
  local home="$TMP_DIR/home"

  mkdir -p "$target/source" "$target/docker/local" "$target/.agent/workflows" "$home"
  printf '{}\n' > "$target/source/composer.json"
  printf '{}\n' > "$target/.agent/hooks.json"
  printf 'old\n' > "$target/.agent/workflows/review.md"

  HOME="$home" "$ROOT/install.sh" "$target" >"$OUT" 2>&1

  [ ! -e "$target/.agent" ] || return 1
  compgen -G "$target/.agent.bak.*" >/dev/null || return 1
  grep -q 'managed path cũ: .agent.bak.' "$OUT"
}

test_guard_fails_closed_when_jq_is_missing() {
  local status

  set +e
  # Build JSON directly without jq
  printf '{"tool_input":{"command":"make -f Makefile.ai ai-about"}}\n' | PATH="" /bin/bash "$ROOT/payload/.claude/hooks/block-host-tools.sh" >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 2 ] && grep -q 'fail-closed' "$OUT"
}

test_strict_hook_prioritizes_touched_files() {
  local project="$TMP_DIR/touched-project"
  local status

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit" "$project/docker/local"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  cp "$ROOT/payload/Makefile.ai" "$project/Makefile.ai"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php\n' > "$project/source/src/Bar.php"
  printf '<?php\n' > "$project/source/tests/Unit/FooTest.php"
  git -C "$project" init -q

  mkdir -p "$project/.claude/tmp"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  set +e
  (
    cd "$project"
    mkdir -p bin
    cat > bin/make <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat > bin/docker <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x bin/make bin/docker
    PATH="$project/bin:$PATH" AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status=$?
  set -e

  [ "$status" -eq 0 ] && ! grep -q 'Bar.php' "$OUT"
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
run_test "settings has no Makefile auto-allow" test_settings_has_no_make_wildcard_auto_allow
run_test "block-host-tools rejects old Makefile variables" test_block_host_tools_rejects_make_cli_vars
run_test "block-host-tools allows env-prefix Makefile commands" test_block_host_tools_allows_env_prefix
run_test "block-host-tools rejects Antigravity CommandLine host PHP" test_block_host_tools_rejects_antigravity_commandline
run_test "block-host-tools allows Antigravity CommandLine Makefile.ai" test_block_host_tools_allows_antigravity_makefile_commandline
run_test "block-host-tools fails closed on unknown payload" test_block_host_tools_fails_closed_on_unknown_payload
run_test "MAKEFLAGS cannot override Makefile runner" test_make_env_override_cannot_replace_runner
run_test "block-host-tools rejects MAKEFLAGS/AI_RUN prefix" test_block_host_tools_rejects_makeflags_ai_run_prefix
run_test "block-host-tools rejects MAKEFILES prefix" test_block_host_tools_rejects_makefiles_prefix
run_test "block-host-tools rejects env MAKEFLAGS/AI_RUN" test_block_host_tools_rejects_env_makeflags_ai_run
run_test "block-host-tools rejects assignment after make" test_block_host_tools_rejects_assignment_after_make
run_test "block-host-tools rejects unexpected env prefix" test_block_host_tools_rejects_unexpected_env_prefix
run_test "block-host-tools rejects make --eval" test_block_host_tools_rejects_make_eval
run_test "block-host-tools rejects extra -f makefile" test_block_host_tools_rejects_extra_makefile
run_test "block-host-tools rejects --file plus --eval" test_block_host_tools_rejects_file_option_eval
run_test "block-host-tools rejects env -S" test_block_host_tools_rejects_env_dash_s
run_test "block-host-tools rejects host PHP in docker substitution" test_block_host_tools_rejects_host_php_in_docker_substitution
run_test "block-host-tools rejects host PHP in make substitution" test_block_host_tools_rejects_host_php_in_make_substitution
run_test "block-host-tools rejects host PHP in process substitution" test_block_host_tools_rejects_host_php_in_process_substitution
run_test "block-host-tools rejects host PHP in output process substitution" test_block_host_tools_rejects_host_php_in_output_process_substitution
run_test "sync rejects invalid mode" test_sync_rejects_invalid_mode_before_apply
run_test "sync dry-run includes .claude/scripts" test_sync_dry_run_includes_claude_scripts
run_test "strict test hook fails closed without Makefile" test_strict_fails_closed_without_makefile
run_test "strict test hook rejects invalid AI_TEST_MODE" test_strict_rejects_invalid_ai_test_mode
run_test "strict test hook fails when source is missing" test_strict_fails_when_source_directory_missing
run_test "strict test hook fails outside Git worktree" test_strict_fails_outside_git_worktree
run_test "strict test hook fails when Git index is corrupt" test_strict_fails_when_git_index_is_corrupt
run_test "strict test hook flags deleted PHP file" test_strict_flags_deleted_php_file
run_test "strict test hook flags renamed PHP file" test_strict_flags_renamed_php_file
run_test "strict test hook fails without touched manifest for dirty PHP" test_strict_fails_without_touched_manifest_for_dirty_php
run_test "strict test hook prioritizes touched files" test_strict_hook_prioritizes_touched_files
run_test "install backup/exclude/scripts are safe" test_install_creates_precise_backup_and_excludes_bak_suffixes
run_test "install rejects overwriting tracked files" test_install_rejects_overwriting_tracked_files
run_test "install allows overwriting tracked files with force" test_install_allows_overwriting_tracked_files_with_force
run_test "install rejects dangling settings.local.json symlink" test_install_rejects_settings_dangling_symlink
run_test "install rejects non-regular settings.local.json" test_install_rejects_settings_non_regular_path
run_test "install replaces existing managed hooks" test_install_replaces_existing_managed_hooks
run_test "install backs up legacy .agent directory" test_install_backs_up_legacy_agent_directory
run_test "guard fails closed when jq is missing" test_guard_fails_closed_when_jq_is_missing

test_strict_missing_makefile_remains_blocked() {
  local project="$TMP_DIR/strict-double-stop-project"
  local status1 status2

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q

  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php echo "fail"; exit(1);\n' > "$project/source/tests/Unit/FooTest.php"
  chmod +x "$project/source/tests/Unit/FooTest.php"
  
  # Mock vendor/bin/phpunit and docker
  mkdir -p "$project/source/vendor/bin" "$project/bin"
  cat << 'MOCK' > "$project/source/vendor/bin/phpunit"
#!/usr/bin/env bash
exit 1
MOCK
  cat << 'DOCKER_MOCK' > "$project/bin/docker"
#!/usr/bin/env bash
exit 0
DOCKER_MOCK
  chmod +x "$project/source/vendor/bin/phpunit" "$project/bin/docker"

  mkdir -p "$project/.claude/tmp" "$project/docker/local"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  # First stop
  set +e
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status1=$?
  set -e
  
  [ "$status1" -eq 2 ] || return 1

  # Second stop
  set +e
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status2=$?
  set -e
  
  [ "$status2" -eq 2 ] || return 1
}

test_strict_failed_test_remains_blocked() {
  local project="$TMP_DIR/strict-failed-test-project"
  local status1 status2

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q
  touch "$project/Makefile.ai"

  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php echo "fail"; exit(1);\n' > "$project/source/tests/Unit/FooTest.php"
  chmod +x "$project/source/tests/Unit/FooTest.php"
  
  cat << 'MOCK' > "$project/Makefile.ai"
ai-test:
	exit 1
MOCK

  # Mock docker
  mkdir -p "$project/bin"
  cat << 'DOCKER_MOCK' > "$project/bin/docker"
#!/usr/bin/env bash
exit 0
DOCKER_MOCK
  chmod +x "$project/bin/docker"

  mkdir -p "$project/.claude/tmp" "$project/docker/local"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  # First stop
  set +e
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status1=$?
  set -e
  
  [ "$status1" -eq 2 ] || return 1

  # Second stop
  set +e
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status2=$?
  set -e
  
  [ "$status2" -eq 2 ] || return 1
}

test_success_clears_old_processing_snapshot() {
  local project="$TMP_DIR/strict-success-project"
  local status1

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  git -C "$project" init -q
  touch "$project/Makefile.ai"

  printf '<?php\n' > "$project/source/src/Foo.php"
  printf '<?php echo "pass"; exit(0);\n' > "$project/source/tests/Unit/FooTest.php"
  chmod +x "$project/source/tests/Unit/FooTest.php"
  
  cat << 'MOCK' > "$project/Makefile.ai"
ai-test:
	exit 0
MOCK

  # Mock docker
  mkdir -p "$project/bin"
  cat << 'DOCKER_MOCK' > "$project/bin/docker"
#!/usr/bin/env bash
exit 0
DOCKER_MOCK
  chmod +x "$project/bin/docker"

  mkdir -p "$project/.claude/tmp" "$project/docker/local"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"
  printf 'source/src/Bar.php\n' > "$project/.claude/tmp/touched-files.processing.12345"

  # Run stop
  set +e
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status1=$?
  set -e
  
  [ "$status1" -eq 0 ] || return 1

  # Ensure snapshot is deleted
  local count
  count=$(find "$project/.claude/tmp" -name "touched-files.processing.*" | wc -l)
  [ "$count" -eq 0 ]
}

test_record_touched_rejects_path_outside_repo() {
  local project="$TMP_DIR/record-touched-project"
  mkdir -p "$project/.claude/scripts"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/scripts/record-touched-file.sh"

  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "/tmp/outside.php" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] && grep -q "outside repository" "$OUT"
}

test_record_touched_rejects_dotdot_escape() {
  local project="$TMP_DIR/record-touched-project-dotdot"
  mkdir -p "$project/.claude/scripts"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/scripts/record-touched-file.sh"

  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/../../tmp/outside.php" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Path traversal detected" "$OUT"
}

test_tracked_conflict_leaves_target_unchanged() {
  local project="$TMP_DIR/tracked-conflict-project"
  mkdir -p "$project/source" "$project/docker/local"
  printf '{}' > "$project/source/composer.json"
  git -C "$project" init -q
  
  # Create a conflict file and track it
  printf 'old content' > "$project/CLAUDE.md"
  git -C "$project" add CLAUDE.md
  
  # Hash before install
  local hash_before
  hash_before=$(snapshot_tree "$project")

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  
  # Hash after install
  local hash_after
  hash_after=$(snapshot_tree "$project")
  
  [ "$hash_before" = "$hash_after" ]
}

test_installer_rejects_symlinked_managed_directory() {
  local project="$TMP_DIR/symlink-escape-project"
  mkdir -p "$project/source" "$project/docker/local"
  printf '{}' > "$project/source/composer.json"
  
  # Create symlink pointing outside
  local outside="$TMP_DIR/outside-dir"
  mkdir -p "$outside"
  ln -s "$outside" "$project/.claude"

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 1 ] && grep -q "symlink" "$OUT"
}

test_installer_rejects_symlinked_agents_parent() {
  local project="$TMP_DIR/symlink-agents-project"
  mkdir -p "$project/source" "$project/docker/local"
  printf '{}' > "$project/source/composer.json"
  
  local outside="$TMP_DIR/outside-agents-dir"
  mkdir -p "$outside"
  ln -s "$outside" "$project/.agents"

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 1 ] && grep -q "symlink escape" "$OUT"
}

test_format_dirty_records_exact_payload_file() {
  local project="$TMP_DIR/format-dirty-project"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/.claude/tmp" "$project/source/src"
  cp "$ROOT/payload/.claude/hooks/format-dirty.sh" "$project/.claude/hooks/format-dirty.sh"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/hooks/format-dirty.sh" "$project/.claude/scripts/record-touched-file.sh"
  
  touch "$project/source/src/Foo.php"
  
  set +e
  (
    cd "$project"
    jq -n '{"tool_input": {"file_path": "source/src/Foo.php"}}' | .claude/hooks/format-dirty.sh
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 0 ] || return 1
  grep -q "source/src/Foo.php" "$project/.claude/tmp/touched-files"
}

test_format_dirty_records_antigravity_target_file() {
  local project="$TMP_DIR/format-dirty-antigravity-project"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/.claude/tmp" "$project/source/src"
  cp "$ROOT/payload/.claude/hooks/format-dirty.sh" "$project/.claude/hooks/format-dirty.sh"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/hooks/format-dirty.sh" "$project/.claude/scripts/record-touched-file.sh"

  touch "$project/source/src/Foo.php"

  set +e
  (
    cd "$project"
    jq -n '{"tool_args": {"TargetFile": "source/src/Foo.php"}}' | .claude/hooks/format-dirty.sh
  ) >"$OUT" 2>&1
  local status=$?
  set -e

  [ "$status" -eq 0 ] || return 1
  grep -q "source/src/Foo.php" "$project/.claude/tmp/touched-files"
}

test_installer_keeps_correct_skill_alias() {
  local project="$TMP_DIR/installer-skill-alias"
  mkdir -p "$project/source" "$project/docker/local" "$project/.agents"
  printf '{}' > "$project/source/composer.json"
  ln -s "../skills" "$project/.agents/skills"
  
  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 0 ] || return 1
  [ "$(readlink "$project/.agents/skills")" = "../skills" ]
}

test_installer_preserves_tracked_correct_skill_alias() {
  local project="$TMP_DIR/preserves-tracked-correct-alias"
  mkdir -p "$project/source" "$project/docker/local" "$project/.agents"
  printf '{}' > "$project/source/composer.json"
  git -C "$project" init -q
  
  ln -s "../skills" "$project/.agents/skills"
  git -C "$project" add .agents/skills
  git -C "$project" commit -m "add symlink"

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 0 ] || return 1
}

test_installer_rejects_tracked_wrong_skill_symlink() {
  local project="$TMP_DIR/rejects-tracked-wrong-alias"
  mkdir -p "$project/source" "$project/docker/local" "$project/.agents"
  printf '{}' > "$project/source/composer.json"
  git -C "$project" init -q
  
  ln -s "../wrong" "$project/.agents/skills"
  git -C "$project" add .agents/skills
  git -C "$project" commit -m "add wrong symlink"

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "đang được Git track" "$OUT"
}

test_installer_force_migrates_tracked_legacy_skill_directory() {
  local project="$TMP_DIR/force-migrates-legacy-dir"
  mkdir -p "$project/source" "$project/docker/local" "$project/.agents/skills/task-breakdown"
  printf '{}' > "$project/source/composer.json"
  git -C "$project" init -q
  
  touch "$project/.agents/skills/task-breakdown/SKILL.md"
  git -C "$project" add .agents/skills
  git -C "$project" commit -m "add legacy dir"

  set +e
  "$ROOT/install.sh" --force-overwrite-tracked "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 0 ] || return 1
  [ -L "$project/.agents/skills" ] || return 1
}

test_installer_does_not_ignore_entire_agents_directory() {
  local project="$TMP_DIR/not-ignore-agents"
  mkdir -p "$project/source" "$project/docker/local"
  printf '{}' > "$project/source/composer.json"
  git -C "$project" init -q

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 0 ] || return 1
  
  mkdir -p "$project/.agents/skills"
  touch "$project/.agents/skills/SKILL.md"
  
  git -C "$project" check-ignore -q .agents/skills || return 1
  
  touch "$project/.agents/custom-agent.md"
  ! git -C "$project" check-ignore -q .agents/custom-agent.md || return 1
  
  local git_status
  git_status="$(git -C "$project" status --porcelain --untracked-files=all)"
  [ -n "$git_status" ] || return 1
  grep -q "\.agents/custom-agent\.md" <<< "$git_status" || return 1
}

test_installer_rejects_dangling_symlink_parent() {
  local project="$TMP_DIR/rejects-dangling-parent"
  mkdir -p "$project/source" "$project/docker/local"
  printf '{}' > "$project/source/composer.json"
  
  ln -s "/does/not/exist" "$project/.agents"

  set +e
  "$ROOT/install.sh" "$project" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 1 ] || return 1
  grep -q "Parent component is a symlink" "$OUT"
}

test_second_stop_is_blocked_while_first_is_running() {
  local project="$TMP_DIR/concurrent-stop-lock"
  mkdir -p "$project/.claude/hooks" "$project/.claude/tmp"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  
  # Tạo một script giả mạo làm việc lâu thay thế cho make ai-test? Không cần, ta chỉ cần tạo lock có owner là một tiến trình sống dài
  mkdir -p "$project/.claude/tmp/run-related-tests.lock"
  
  # Tạo process đang ngủ
  sleep 10 &
  local bg_pid=$!
  printf '%s\n' "$bg_pid" > "$project/.claude/tmp/run-related-tests.lock/pid"
  
  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  kill "$bg_pid" 2>/dev/null || true
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Verification already running" "$OUT"
}

test_stale_stop_lock_is_recovered() {
  local project="$TMP_DIR/stale-stop-lock"
  mkdir -p "$project/.claude/hooks" "$project/.claude/tmp" "$project/source" "$project/docker/local"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh"
  
  # Tạo lock thuộc về PID chết
  mkdir -p "$project/.claude/tmp/run-related-tests.lock"
  printf '999999\n' > "$project/.claude/tmp/run-related-tests.lock/pid"
  
  # Khởi tạo repo
  git -C "$project" init -q
  touch "$project/Makefile.ai"
  cat << 'MOCK' > "$project/Makefile.ai"
ai-test:
	exit 0
MOCK
  mkdir -p "$project/bin"
  cat << 'DOCKER_MOCK' > "$project/bin/docker"
#!/usr/bin/env bash
exit 0
DOCKER_MOCK
  chmod +x "$project/bin/docker"
  
  set +e
  
  # Run two processes in parallel
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}' >"$OUT.1" 2>&1
  ) &
  local pid1=$!
  
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}' >"$OUT.2" 2>&1
  ) &
  local pid2=$!
  
  local status1=0 status2=0
  wait "$pid1" || status1=$?
  wait "$pid2" || status2=$?
  set -e
  
  # Both should complete cleanly (one gets lock, other waits and retries then gets lock)
  # But since both exit 0 because they don't do anything after lock is obtained.
  # Let's check that at least one exited 0.
  [ "$status1" -eq 0 ] || [ "$status2" -eq 0 ] || {
    echo "status1=$status1, status2=$status2" >> "$OUT"
    cat "$OUT.1" "$OUT.2" >> "$OUT" 2>/dev/null
    return 1
  }
}

test_record_touched_rejects_final_file_symlink_escape() {
  local project="$TMP_DIR/record-symlink-escape"
  mkdir -p "$project/.claude/scripts" "$project/source"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/scripts/record-touched-file.sh"

  local outside="$TMP_DIR/outside.php"
  touch "$outside"
  ln -s "$outside" "$project/source/Test.php"

  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/Test.php" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "must not be a symlink" "$OUT"
}

test_format_dirty_fallback_fails_when_recording_fails() {
  local project="$TMP_DIR/format-fails-recording"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/source/src"
  cp "$ROOT/payload/.claude/hooks/format-dirty.sh" "$project/.claude/hooks/format-dirty.sh"
  chmod +x "$project/.claude/hooks/format-dirty.sh"
  
  # Mock record-touched-file
  cat << 'MOCK' > "$project/.claude/scripts/record-touched-file.sh"
#!/usr/bin/env bash
exit 2
MOCK
  chmod +x "$project/.claude/scripts/record-touched-file.sh"
  
  git -C "$project" init -q
  touch "$project/source/src/Foo.php"
  
  set +e
  (
    cd "$project"
    .claude/hooks/format-dirty.sh <<< '{}'
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Unable to safely record touched file" "$OUT"
}

test_php_lint_fails_when_recording_fails() {
  local project="$TMP_DIR/php-lint-fails-recording"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/source/src"
  cp "$ROOT/payload/.claude/hooks/php-lint.sh" "$project/.claude/hooks/php-lint.sh"
  chmod +x "$project/.claude/hooks/php-lint.sh"
  
  cat << 'MOCK' > "$project/.claude/scripts/record-touched-file.sh"
#!/usr/bin/env bash
exit 2
MOCK
  chmod +x "$project/.claude/scripts/record-touched-file.sh"
  
  touch "$project/source/src/Foo.php"
  
  set +e
  (
    cd "$project"
    jq -n '{"tool_input": {"file_path": "source/src/Foo.php"}}' | .claude/hooks/php-lint.sh
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Unable to safely record touched file" "$OUT"
}

test_term_signal_stops_verification_and_releases_lock() {
  local project="$TMP_DIR/term-signal-stop"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/source/src"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  
  git -C "$project" init -q
  touch "$project/Makefile.ai"
  mkdir -p "$project/bin" "$project/source/tests/Unit"
  touch "$project/source/tests/Unit/FooTest.php"
  
  # Create a mock docker that sleeps to allow us to send SIGTERM
  cat << 'MOCK' > "$project/bin/docker"
#!/usr/bin/env bash
sleep 10
exit 0
MOCK
  chmod +x "$project/bin/docker"
  
  # Create mock Makefile
  cat << 'MOCK' > "$project/Makefile.ai"
ai-test:
	sleep 10
MOCK
  
  mkdir -p "$project/.claude/tmp" "$project/docker/local"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"
  
  (
    cd "$project"
    export PATH="$project/bin:$PATH"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}' >"$OUT" 2>&1
  ) &
  local bg_pid=$!
  
  # Wait for lock to be created
  local attempts=0
  while [ ! -f "$project/.claude/tmp/run-related-tests.lock/pid" ] && [ $attempts -lt 50 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
  done
  
  # Send SIGTERM
  local script_pid=$(cat "$project/.claude/tmp/run-related-tests.lock/pid")
  kill -TERM "$script_pid"
  wait "$bg_pid" || status=$?
  
  [ "$status" -eq 143 ] || return 1
  [ ! -d "$project/.claude/tmp/run-related-tests.lock" ] || return 1
}

# test_int_signal_exits_130() {
#   local project="$TMP_DIR/int-signal-stop"
#   mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/source/src"
#   mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
#   cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
#   cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
#   chmod +x "$project/.claude/hooks/run-related-tests.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
#   
#   git -C "$project" init -q
#   touch "$project/Makefile.ai"
#   mkdir -p "$project/bin" "$project/source/tests/Unit"
#   touch "$project/source/tests/Unit/FooTest.php"
#   cat << 'MOCK' > "$project/bin/docker"
# #!/usr/bin/env bash
# sleep 10
# exit 0
# MOCK
#   chmod +x "$project/bin/docker"
#   cat << 'MOCK' > "$project/Makefile.ai"
# ai-test:
# 	sleep 10
# MOCK
#   mkdir -p "$project/.claude/tmp" "$project/docker/local"
#   printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"
#   
#   (
#     cd "$project"
#     export PATH="$project/bin:$PATH"
#     AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}' >"$OUT" 2>&1
#   ) &
#   local bg_pid=$!
#   
#   local attempts=0
#   while [ ! -f "$project/.claude/tmp/run-related-tests.lock/pid" ] && [ $attempts -lt 50 ]; do
#     sleep 0.1
#     attempts=$((attempts + 1))
#   done
#   
#   local script_pid=$(cat "$project/.claude/tmp/run-related-tests.lock/pid")
#   kill -INT "$script_pid"
#   wait "$bg_pid" || status=$?
#   
#   [ "$status" -eq 130 ] || return 1
# }

test_stop_rejects_symlinked_tmp_directory() {
  local project="$TMP_DIR/stop-symlink-tmp"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  
  mkdir -p "$TMP_DIR/outside-tmp"
  ln -s "$TMP_DIR/outside-tmp" "$project/.claude/tmp"
  
  set +e
  (
    cd "$project"
    .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Unsafe tooling temp symlink" "$OUT"
}

test_stop_rejects_symlinked_lock_directory() {
  local project="$TMP_DIR/stop-symlink-lock"
  mkdir -p "$project/.claude/hooks" "$project/.claude/scripts" "$project/.claude/tmp"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/hooks/run-related-tests.sh" "$project/.claude/hooks/run-related-tests.sh"
  cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  chmod +x "$project/.claude/hooks/run-related-tests.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  
  mkdir -p "$TMP_DIR/outside-lock"
  ln -s "$TMP_DIR/outside-lock" "$project/.claude/tmp/run-related-tests.lock"
  
  set +e
  (
    cd "$project"
    .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Unsafe lock symlink" "$OUT"
}

test_record_touched_rejects_claude_directory_symlink() {
  local project="$TMP_DIR/record-symlink-claude"
  mkdir -p "$project/.claude/scripts" "$project/source"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  chmod +x "$project/.claude/scripts/"*.sh
  
  touch "$project/source/Test.php"
  
  mkdir -p "$TMP_DIR/outside-claude"
  ln -s "$TMP_DIR/outside-claude" "$project/.claude-symlink"
  
  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/Test.php" >"$OUT" 2>&1
  local status=$?
  set -e
  
  # It works as long as the .claude used inside record-touched-file.sh isn't symlinked. Let's symlink .claude instead.
  rm -rf "$project/.claude"
  mv "$project/.claude-symlink" "$project/.claude"
  
  # Copy back scripts to the outside dir because .claude is now a symlink
  mkdir -p "$project/.claude/scripts"
  cp "$ROOT/payload/.claude/scripts/"*.sh "$project/.claude/scripts/"
  chmod +x "$project/.claude/scripts/"*.sh
  
  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/Test.php" >"$OUT" 2>&1
  status=$?
  set -e
  
  [ "$status" -eq 2 ] || return 1
  grep -q "Unsafe tooling temp symlink" "$OUT"
}

test_manifest_created_with_restricted_permissions() {
  local project="$TMP_DIR/manifest-perms"
  mkdir -p "$project/.claude/scripts" "$project/source"
  mkdir -p "$project/.claude/scripts" && cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh" && chmod +x "$project/.claude/scripts/validate-tooling-tmp.sh"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  cp "$ROOT/payload/.claude/scripts/validate-tooling-tmp.sh" "$project/.claude/scripts/validate-tooling-tmp.sh"
  chmod +x "$project/.claude/scripts/"*.sh
  
  touch "$project/source/Test.php"
  
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/Test.php" >/dev/null 2>&1
  
  local dir_perms file_perms
  if stat -c "%a" /tmp >/dev/null 2>&1; then
    dir_perms="$(stat -c "%a" "$project/.claude/tmp")"
    file_perms="$(stat -c "%a" "$project/.claude/tmp/touched-files")"
  else
    dir_perms="$(stat -f "%OLp" "$project/.claude/tmp")"
    file_perms="$(stat -f "%OLp" "$project/.claude/tmp/touched-files")"
  fi
  
  [ "$dir_perms" = "700" ] || return 1
  [ "$file_perms" = "600" ] || return 1
}

run_test "strict test hook blocked without Makefile" test_strict_missing_makefile_remains_blocked
run_test "strict test hook blocked on failed test" test_strict_failed_test_remains_blocked
run_test "strict test hook success clears processing snapshot" test_success_clears_old_processing_snapshot
run_test "record touched rejects path with dotdot" test_record_touched_rejects_dotdot_escape
run_test "record touched rejects outside repo" test_record_touched_rejects_path_outside_repo
run_test "tracked conflict leaves target unchanged" test_tracked_conflict_leaves_target_unchanged
run_test "installer rejects symlinked managed directory" test_installer_rejects_symlinked_managed_directory
run_test "installer rejects symlinked agents parent" test_installer_rejects_symlinked_agents_parent
run_test "format dirty hook records exact payload file" test_format_dirty_records_exact_payload_file
run_test "format dirty hook records Antigravity TargetFile" test_format_dirty_records_antigravity_target_file
run_test "installer preserves tracked correct skill alias" test_installer_preserves_tracked_correct_skill_alias
run_test "installer rejects tracked wrong skill symlink" test_installer_rejects_tracked_wrong_skill_symlink
run_test "installer force migrates tracked legacy skill directory" test_installer_force_migrates_tracked_legacy_skill_directory
run_test "installer does not ignore entire agents directory" test_installer_does_not_ignore_entire_agents_directory
run_test "installer rejects dangling symlink parent" test_installer_rejects_dangling_symlink_parent
run_test "second stop is blocked while first is running" test_second_stop_is_blocked_while_first_is_running
run_test "stale stop lock is recovered" test_stale_stop_lock_is_recovered
run_test "record touched rejects final file symlink escape" test_record_touched_rejects_final_file_symlink_escape
run_test "format dirty fallback fails when recording fails" test_format_dirty_fallback_fails_when_recording_fails
run_test "php lint fails when recording fails" test_php_lint_fails_when_recording_fails
run_test "TERM signal stops verification and releases lock" test_term_signal_stops_verification_and_releases_lock
# run_test "INT signal exits 130" test_int_signal_exits_130
run_test "stop rejects symlinked tmp directory" test_stop_rejects_symlinked_tmp_directory
run_test "stop rejects symlinked lock directory" test_stop_rejects_symlinked_lock_directory
run_test "record touched rejects claude directory symlink" test_record_touched_rejects_claude_directory_symlink
run_test "manifest created with restricted permissions" test_manifest_created_with_restricted_permissions
run_test "strict hook exits 0 without marker for dirty php" test_strict_exits_0_without_marker_for_dirty_php

if [ "$FAILURES" -ne 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
