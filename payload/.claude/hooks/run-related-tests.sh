#!/usr/bin/env bash
# Stop hook: map file PHP đã đổi -> file *Test.php tương ứng trong source/tests/, chạy những cái TỒN TẠI.
#
# Format KHÔNG check ở đây: PostToolUse (php-lint.sh) đã auto-format từng file AI sửa rồi.
#
# AI_TEST_MODE (env):
#   strict    — UNVERIFIED/test fail → exit 2 (mặc định cho Stop hook)
#   advisory  — UNVERIFIED → cảnh báo + exit 0; chỉ dùng khi user chủ động set env cho cả phiên
# Stop hook không tự đổi mode theo slash command; đừng giả định /implement tự chuyển advisory.
#
# v1.6: AI_TEST_MODE advisory/strict; v1.4: bỏ host fallback.
# Exit 0 = OK; exit 2 = có lỗi hoặc UNVERIFIED (strict), báo ngược cho AI.
set -uo pipefail

TEST_MODE="${AI_TEST_MODE:-strict}"
case "$TEST_MODE" in
  strict | advisory) ;;
  *)
    echo "[run-related-tests hook] Invalid AI_TEST_MODE: $TEST_MODE (expected strict|advisory)" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/source"
INPUT="$(cat)"
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
    exit 0
  fi
fi

unverified() {
  echo "[run-related-tests hook] ⚠️ UNVERIFIED — $1" >&2
  if [ "$TEST_MODE" = "strict" ]; then
    echo "[mode=strict] Chặn: không thể xác minh test liên quan." >&2
    exit 2
  fi
  exit 0
}

[ -d "$SRC" ] || unverified "source directory không tồn tại: $SRC"
cd "$SRC" || unverified "không thể truy cập source directory: $SRC"

git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  unverified "không xác định được Git working tree"

CHANGED_FILES_TMP="$(mktemp "${TMPDIR:-/tmp}/run-related-tests.changed.XXXXXX")"
GIT_ERRORS_TMP="$(mktemp "${TMPDIR:-/tmp}/run-related-tests.git-errors.XXXXXX")"
trap 'rm -f "$CHANGED_FILES_TMP" "$GIT_ERRORS_TMP"' EXIT

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

append_diff_paths() {
  mode_arg="$1"
  output=""

  if [ -n "$mode_arg" ]; then
    output="$(git -C "$REPO_ROOT" diff "$mode_arg" --name-status -M --diff-filter=ACMRD 2>>"$GIT_ERRORS_TMP")" ||
      unverified "Không thể thu thập danh sách file thay đổi từ Git: $(cat "$GIT_ERRORS_TMP")"
  else
    output="$(git -C "$REPO_ROOT" diff --name-status -M --diff-filter=ACMRD 2>>"$GIT_ERRORS_TMP")" ||
      unverified "Không thể thu thập danh sách file thay đổi từ Git: $(cat "$GIT_ERRORS_TMP")"
  fi

  printf '%s\n' "$output" | awk -F '\t' '
    NF >= 2 {
      if ($1 ~ /^[RC]/) {
        print $2
        if (NF >= 3) print $3
      } else {
        print $2
      }
    }
  ' >> "$CHANGED_FILES_TMP"
}

collect_changed_once() {
  : > "$CHANGED_FILES_TMP"
  : > "$GIT_ERRORS_TMP"

  append_diff_paths ""
  append_diff_paths "--cached"

  git -C "$REPO_ROOT" ls-files --others --exclude-standard >> "$CHANGED_FILES_TMP" 2>>"$GIT_ERRORS_TMP" ||
    unverified "Không thể thu thập danh sách file thay đổi từ Git: $(cat "$GIT_ERRORS_TMP")"
}

# Danh sách file PHP đã đổi (unstaged + staged + untracked)
collect_changed() {
  cat "$CHANGED_FILES_TMP"
}

collect_changed_once

# Tương thích bash 3.2 (macOS) — không dùng associative array.
# Gom ứng viên test (đường dẫn tương đối source/), mỗi dòng 1 file.
candidates=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *.php) ;;
    *) continue ;;
  esac
  case "$f" in
    source/tests/*Test.php)            # file test đổi trực tiếp
      candidates="${candidates}
${f#source/}"
      ;;
    source/*)                          # ClassName.php -> tìm ClassNameTest.php trong tests/
      base="$(basename "$f" .php)"
      while IFS= read -r t; do
        candidates="${candidates}
${t}"
      done < <(find tests -type f -name "${base}Test.php" 2>/dev/null)
      ;;
  esac
done < <(collect_changed | sort -u)

# Lọc unique + chỉ giữ file tồn tại
tests_to_run=""
while IFS= read -r t; do
  [ -z "$t" ] && continue
  [ -f "$t" ] || continue
  tests_to_run="${tests_to_run} ${t}"
done < <(printf '%s\n' "$candidates" | sort -u)

tests_to_run="$(printf '%s' "$tests_to_run" | sed 's/^ *//')"

# Không có paired test → hành vi phụ thuộc AI_TEST_MODE
if [ -z "$tests_to_run" ]; then
  changed_php="$(collect_changed | sort -u | grep '\.php$' | grep -v 'Test\.php$' || true)"
  if [ -n "$changed_php" ]; then
    {
      echo "[run-related-tests hook] ⚠️ UNVERIFIED — không tìm thấy paired test cho:"
      printf '%s\n' "$changed_php" | head -8 | sed 's/^/  - /'
      echo ""
      echo "Điều này không có nghĩa thay đổi đã an toàn."
      echo "Cần chọn test thủ công hoặc chạy test module trước khi hoàn tất."
      if [ "$TEST_MODE" = "strict" ]; then
        echo "[mode=strict] Chặn: chưa có test xác minh. Đặt AI_TEST_MODE=advisory để chỉ cảnh báo."
      fi
    } >&2
  fi
  if [ "$TEST_MODE" = "strict" ] && [ -n "$changed_php" ]; then
    exit 2
  fi
  exit 0
fi

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  unverified "Makefile.ai không tồn tại. Cần cài tooling hoặc chạy test thủ công trong container."
fi

if ! container_up; then
  {
    echo "[run-related-tests hook] ⚠️ UNVERIFIED — container hrm-api không chạy."
    echo "Bật Docker rồi chạy test liên quan:"
    printf '%s\n' "$tests_to_run" | tr ' ' '\n' | sed '/^$/d; s#^#  AI_TEST=#; s#$# make -f Makefile.ai ai-test#'
    if [ "$TEST_MODE" = "strict" ]; then
      echo "[mode=strict] Chặn: không thể xác minh test liên quan."
    fi
  } >&2
  [ "$TEST_MODE" = "strict" ] && exit 2
  exit 0
fi

while IFS= read -r test_file; do
  [ -z "$test_file" ] && continue
  if ! AI_TEST="$test_file" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-test; then
    echo "[run-related-tests hook] Unit test FAILED: ${test_file}" >&2
    exit 2
  fi
done < <(printf '%s\n' "$tests_to_run" | tr ' ' '\n' | sed '/^$/d')

exit 0
