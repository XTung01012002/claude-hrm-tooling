#!/usr/bin/env bash
sed -i 's/test_strict_failure_remains_blocked_on_second_stop/test_strict_missing_makefile_remains_blocked/g' tests/tooling-security.sh

sed -i 's/sha256sum/shasum -a 256/g' tests/tooling-security.sh

cat << 'TESTS' >> tests/tooling-security.tmp
test_strict_failed_test_remains_blocked() {
  local project="$TMP_DIR/strict-failed-test-project"
  local status1 status2

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
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

  mkdir -p "$project/.claude/tmp"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  # First stop
  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status1=$?
  set -e
  
  [ "$status1" -eq 2 ] || return 1

  # Second stop
  set +e
  (
    cd "$project"
    AI_TEST_MODE=strict .claude/hooks/run-related-tests.sh <<< '{}'
  ) >"$OUT" 2>&1
  status2=$?
  set -e
  
  [ "$status2" -eq 2 ] || return 1
}

test_success_clears_old_processing_snapshot() {
  local project="$TMP_DIR/strict-success-project"
  local status1 status2

  mkdir -p "$project/.claude/hooks" "$project/source/src" "$project/source/tests/Unit"
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

  mkdir -p "$project/.claude/tmp"
  printf 'source/src/Foo.php\n' > "$project/.claude/tmp/touched-files"

  # Run stop
  set +e
  (
    cd "$project"
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

test_record_touched_rejects_dotdot_escape() {
  local project="$TMP_DIR/record-touched-project-dotdot"
  mkdir -p "$project/.claude/scripts"
  cp "$ROOT/payload/.claude/scripts/record-touched-file.sh" "$project/.claude/scripts/record-touched-file.sh"
  chmod +x "$project/.claude/scripts/record-touched-file.sh"

  set +e
  "$project/.claude/scripts/record-touched-file.sh" "$project" "source/../../tmp/outside.php" >"$OUT" 2>&1
  local status=$?
  set -e
  
  [ "$status" -eq 1 ] && grep -q "Path traversal detected" "$OUT"
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

TESTS

cat fix_tests.sh
