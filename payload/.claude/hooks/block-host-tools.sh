#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# BEST-EFFORT guard: chặn AI vô tình chạy PHP/Composer/Pint/PHPUnit trên host.
# Không phải enforcement tuyệt đối — edge cases vẫn có thể bypass.
#
# Logic:
#   1. Match ở VỊ TRÍ COMMAND (sau ; & | ( hoặc đầu dòng), kể cả qua wrapper
#      (sudo/env/time/command). "rg php" / "echo php" / "git grep composer" KHÔNG bị chặn.
#   2. Bắt absolute paths: /usr/bin/php, /usr/local/bin/composer, ...
#   3. Bắt subshell: bash -c 'php ...' — dùng command-position matching trên nội dung.
#   4. Cho phép nếu lệnh nguy hiểm nằm trong docker/make context.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$COMMAND" ] && exit 0

# --- Patterns ---
# Vị trí command = đầu dòng (^) hoặc sau command separator (; & | ()
SEP='(^|[;&|()])'
# Transparent wrappers: sudo php, env composer, time vendor/bin/phpunit, ...
WRAP='((sudo|env|command|time)[[:space:]]+)*'

# 1) Bare: php/composer ở vị trí command (có thể qua wrapper)
PAT_BARE="${SEP}[[:space:]]*${WRAP}(php|composer)([[:space:]]|$)"
# 2) Vendor tools: bắt cả ./vendor, source/vendor
PAT_VENDOR="${SEP}[[:space:]]*${WRAP}(\./|source/)*(vendor/bin/(phpunit|pint))([[:space:]]|$)"
# 3) Absolute path: /usr/bin/php, /opt/homebrew/bin/composer, ...
PAT_ABSPATH="${SEP}[[:space:]]*${WRAP}/[^[:space:]]*/(php|composer|phpunit|pint)([[:space:]]|$)"

ALL_PATS="$PAT_BARE|$PAT_VENDOR|$PAT_ABSPATH"

check_dangerous() {
  # Trả 0 (true) nếu chuỗi $1 chứa lệnh nguy hiểm ở vị trí command
  printf '%s' "$1" | grep -qE "$ALL_PATS"
}

strip_safe_contexts() {
  # Xóa các docker/make contexts → chỉ giữ phần chạy trên host
  printf '%s' "$1" | sed -E \
    's/(docker compose exec|docker-compose exec|docker exec)[^;&|]*/SAFE/g; s/make -f Makefile\.ai[^;&|]*/SAFE/g'
}

BLOCK=0

# Check 1: command-position patterns trên toàn bộ command
if check_dangerous "$COMMAND"; then
  BLOCK=1
fi

# Check 2: subshell wrapping — extract nội dung sau -c, áp dụng command-position matching
SUBCMD=$(printf '%s' "$COMMAND" | sed -nE "s/.*(bash|sh)[[:space:]]+-[a-z]*c[[:space:]]+['\"]?(.*)/\2/p" | sed "s/['\"]$//" | head -1)
if [ -n "$SUBCMD" ] && check_dangerous "$SUBCMD"; then
  BLOCK=1
fi

if [ "$BLOCK" = "1" ]; then
  # Whitelist: strip docker/make contexts, kiểm tra phần còn lại
  STRIPPED=$(strip_safe_contexts "$COMMAND")
  STILL_DANGEROUS=0
  if check_dangerous "$STRIPPED"; then
    STILL_DANGEROUS=1
  fi
  # Cũng check subshell trên stripped
  SUB_STRIPPED=$(printf '%s' "$STRIPPED" | sed -nE "s/.*(bash|sh)[[:space:]]+-[a-z]*c[[:space:]]+['\"]?(.*)/\2/p" | sed "s/['\"]$//" | head -1)
  if [ -n "$SUB_STRIPPED" ] && check_dangerous "$SUB_STRIPPED"; then
    STILL_DANGEROUS=1
  fi

  if [ "$STILL_DANGEROUS" = "0" ]; then
    exit 0
  fi
  echo "🚨 LỖI (PreToolUse Guard): Phát hiện PHP/Composer/Pint/PHPUnit chạy trên môi trường host!" >&2
  echo "❌ Việc này bị NGHIÊM CẤM — host chạy PHP version khác với container (8.2.31), gây báo xanh giả." >&2
  echo "✅ 👉 Hãy sử dụng: \`make -f Makefile.ai ai-lint/ai-test/ai-php\` hoặc \`docker compose exec hrm-api ...\`." >&2
  exit 2
fi

exit 0
