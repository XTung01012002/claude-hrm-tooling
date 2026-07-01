#!/usr/bin/env bash
# Stop hook: map file PHP đã đổi -> file *Test.php tương ứng trong source/tests/, chạy những cái TỒN TẠI.
# Không có paired test -> skip êm (KHÔNG chạy full suite) để hook nhẹ, không làm AI khựng.
#
# Format KHÔNG check ở đây: PostToolUse (php-lint.sh) đã auto-format từng file AI sửa rồi.
#
# v1.4: bỏ host fallback — Docker down thì skip rõ ràng.
# Exit 0 = OK; exit 2 = có lỗi, báo ngược cho AI sửa.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/source"
INPUT="$(cat)"
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
    exit 0
  fi
fi

[ -d "$SRC" ] || exit 0
cd "$SRC" || exit 0

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

# Danh sách file PHP đã đổi (unstaged + staged + untracked)
collect_changed() {
  git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM 2>/dev/null
  git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM --cached 2>/dev/null
  git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null
}

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

# Không có paired test -> skip êm
[ -z "$tests_to_run" ] && exit 0

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  echo "[run-related-tests hook] ⚠️ Makefile.ai không tồn tại — bỏ qua test. Chạy tay: make -f Makefile.ai ai-test TEST=$tests_to_run" >&2
  exit 0
fi

if ! container_up; then
  echo "[run-related-tests hook] ⚠️ Container hrm-api không chạy — bỏ qua test. Bật Docker rồi chạy tay: make -f Makefile.ai ai-test TEST=$tests_to_run" >&2
  exit 0
fi

if ! make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-test TEST="$tests_to_run"; then
  echo "[run-related-tests hook] Unit test FAILED: ${tests_to_run}" >&2
  exit 2
fi
exit 0
