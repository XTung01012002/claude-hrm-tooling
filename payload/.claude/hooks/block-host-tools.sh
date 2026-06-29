#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# Block running tools on host, forcing AI to use Makefile.ai/docker.
set -uo pipefail

# Cần jq để parse payload hook
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$COMMAND" ] && exit 0

if printf '%s' "$COMMAND" | grep -qE '(^|[;&|()])[[:space:]]*(php|composer|vendor/bin/phpunit|vendor/bin/pint)([[:space:]]|$)'; then
  # Kiểm tra xem có bọc trong docker/make.ai không
  if ! printf '%s' "$COMMAND" | grep -qE "docker compose|docker-compose|make -f Makefile.ai|docker exec"; then
    echo "🚨 LỖI (PreToolUse Guard): Bạn đang cố chạy PHP/Composer/Pint/PHPUnit trên môi trường host!" >&2
    echo "❌ Việc này bị NGHIÊM CẤM bởi cấu hình dự án vì host chạy PHP version khác với container (8.2.31), gây ra lỗi báo xanh giả." >&2
    echo "✅ 👉 Hãy sử dụng: \`make -f Makefile.ai ai-lint/ai-test/ai-php\` hoặc \`docker compose exec hrm-api ...\`." >&2
    exit 2
  fi
fi

exit 0
