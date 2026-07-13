#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash/run_command).
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

unsupported_payload() {
  echo "🚨 LỖI (PreToolUse Guard): Không đọc được command từ hook payload; guard fail-closed." >&2
  echo "✅ Payload hỗ trợ: .tool_args.CommandLine (Antigravity) hoặc .tool_input.command (Claude/Codex)." >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || {
  echo "🚨 LỖI (PreToolUse Guard): Không tìm thấy 'jq'; guard fail-closed để tránh bỏ lọt lệnh host." >&2
  exit 2
}

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '
  .tool_args.CommandLine //
  .tool_input.command //
  empty
' 2>/dev/null)" || unsupported_payload
[ -n "$COMMAND" ] || unsupported_payload

block_host_tool() {
  echo "🚨 LỖI (PreToolUse Guard): Guard phát hiện PHP/Composer/Pint/PHPUnit có thể đang chạy trên môi trường host!" >&2
  echo "❌ Tránh thực thi trên host — host chạy PHP version khác với container (8.2.31), gây báo xanh giả." >&2
  echo "✅ 👉 Hãy sử dụng: \`AI_FILE=source/path/File.php make -f Makefile.ai ai-lint\`, \`AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test\` hoặc \`make -f Makefile.ai ai-php-version\`." >&2
  exit 2
}

contains_makefile_ai() {
  printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];&|()]|/)(g?make)([[:space:]]|$|[^;&|()]*[[:space:]])[^;&|()]*Makefile\.ai'
}

is_safe_makefile_ai_command() {
  case "$COMMAND" in
    *$'\n'* | *'..'*) return 1 ;;
  esac

  file_path='source/[A-Za-z0-9_./-]+\.php'
  test_path='tests/[A-Za-z0-9_./-]+Test\.php'
  route_path='[A-Za-z0-9_./:{}-]+'

  printf '%s' "$COMMAND" | grep -Eq '^make[[:space:]]+-f[[:space:]]+Makefile\.ai[[:space:]]+(ai-php-version|ai-migrate-status|ai-about|ai-event-list|ai-route-list)$' ||
    printf '%s' "$COMMAND" | grep -Eq '^AI_FILE='"$file_path"'[[:space:]]+make[[:space:]]+-f[[:space:]]+Makefile\.ai[[:space:]]+(ai-lint|ai-pint|ai-pint-check|ai-check)$' ||
    printf '%s' "$COMMAND" | grep -Eq '^AI_TEST='"$test_path"'[[:space:]]+make[[:space:]]+-f[[:space:]]+Makefile\.ai[[:space:]]+ai-test$' ||
    printf '%s' "$COMMAND" | grep -Eq '^AI_ROUTE_PATH='"$route_path"'[[:space:]]+make[[:space:]]+-f[[:space:]]+Makefile\.ai[[:space:]]+ai-route-list$'
}

# GNU Make can execute host commands while parsing options, environment and
# extra makefiles (`--eval`, `-f`, `MAKEFILES`, `env -S`, command-line vars).
# If Makefile.ai is involved, allow only exact known-safe command shapes.
if contains_makefile_ai; then
  if ! is_safe_makefile_ai_command; then
    echo "🚨 LỖI (PreToolUse Guard): Command Makefile.ai không khớp allow-list an toàn." >&2
    echo "✅ Dùng đúng một shape, ví dụ: \`make -f Makefile.ai ai-about\`, \`AI_FILE=source/path/File.php make -f Makefile.ai ai-lint\`, hoặc \`AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test\`." >&2
    exit 2
  fi
fi

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
TOOL_WORD='((/[^[:space:];&|()`"'"'"']*/)?(php|composer|phpunit|pint)|(\./|source/)*vendor/bin/(phpunit|pint))'

check_dangerous() {
  # Trả 0 (true) nếu chuỗi $1 chứa lệnh nguy hiểm ở vị trí command
  printf '%s' "$1" | grep -qE "$ALL_PATS"
}

check_dangerous_substitution() {
  # Command substitution executes on the host before docker/make receives argv.
  printf '%s' "$1" | grep -qE '\$\([^)]*'"$TOOL_WORD" ||
    printf '%s' "$1" | grep -qE '`[^`]*'"$TOOL_WORD" ||
    printf '%s' "$1" | grep -qE '[<>]\([^)]*'"$TOOL_WORD"
}

strip_safe_contexts() {
  # Xóa các docker/make contexts → chỉ giữ phần chạy trên host
  printf '%s' "$1" | sed -E \
    's/(docker compose exec|docker-compose exec|docker exec)[^;&|]*/SAFE/g; s/make -f Makefile\.ai[^;&|]*/SAFE/g'
}

BLOCK=0

if check_dangerous_substitution "$COMMAND"; then
  block_host_tool
fi

# Check 1: command-position patterns trên toàn bộ command
if check_dangerous "$COMMAND"; then
  BLOCK=1
fi

# Check 2: subshell wrapping — extract nội dung sau -c, áp dụng command-position matching
SUBCMD=$(printf '%s' "$COMMAND" | sed -nE "s/.*(bash|sh)[[:space:]]+-[a-z]*c[[:space:]]+['\"]?(.*)/\2/p" | sed "s/['\"]$//" | head -1)
if [ -n "$SUBCMD" ] && check_dangerous "$SUBCMD"; then
  block_host_tool
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
  block_host_tool
fi

exit 0
