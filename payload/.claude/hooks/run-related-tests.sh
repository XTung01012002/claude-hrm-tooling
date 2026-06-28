#!/usr/bin/env bash
# Stop hook: map file PHP đã đổi -> file *Test.php tương ứng trong source/tests/, chạy những cái TỒN TẠI.
# Không có paired test -> skip êm (KHÔNG chạy full suite) để hook nhẹ, không làm AI khựng.
#
# Format KHÔNG check ở đây: PostToolUse (php-lint.sh) đã auto-format từng file AI sửa rồi.
# (Nếu check pint --dirty --test ở Stop sẽ fail vì file dirty CÓ SẴN từ trước, không phải do AI → khựng mỗi lượt.)
#
# Runner: vendor/bin/phpunit (chạy được local trên PHP 8.5 cho unit test thuần).
# Feature test / php artisan test cần boot app -> chạy trong Docker, không nằm trong hook này.
# Exit 0 = OK; exit 2 = có lỗi, báo ngược cho AI sửa.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/source"
cat >/dev/null 2>&1 || true   # drain stdin (không dùng)

[ -d "$SRC" ] || exit 0
cd "$SRC" || exit 0

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

# Đường dẫn test trong repo này không có khoảng trắng -> word-splitting an toàn.
# shellcheck disable=SC2086
if ! vendor/bin/phpunit $tests_to_run; then
  echo "[run-related-tests hook] Unit test FAILED: ${tests_to_run}" >&2
  exit 2
fi
exit 0
