#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write).
# Lint (php -l) + auto-format (Pint) FILE vừa được Edit/Write nếu là .php.
# Đọc JSON hook từ stdin. Exit 0 = không chặn; exit 2 = chặn & báo ngược cho AI sửa.
#
# Tham chiếu: https://docs.anthropic.com/en/docs/claude-code/hooks
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT="$(cat)"

# Lấy đường dẫn file với fallback nhiều key (các tool/biến thể đặt tên khác nhau)
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.target_file // .tool_input.targetFile // empty' 2>/dev/null)"
[ -z "$FILE" ] && exit 0

# Chỉ xử lý .php
case "$FILE" in
  *.php) ;;
  *) exit 0 ;;
esac

# Chuẩn hóa về absolute path từ repo root (path có thể tương đối kiểu source/src/...).
# KHÔNG cd source rồi nối — sẽ thành đường dẫn sai.
case "$FILE" in
  /*) ABS="$FILE" ;;
  *)  ABS="$REPO_ROOT/$FILE" ;;
esac
[ -f "$ABS" ] || exit 0

# 1) Kiểm tra cú pháp — chặn nếu lỗi
if ! php -l "$ABS" >/dev/null 2>&1; then
  {
    echo "[php-lint hook] php -l FAILED:"
    php -l "$ABS" 2>&1
  } >&2
  exit 2
fi

# 2) Auto-format bằng Pint (không chặn nếu Pint không có)
PINT="$REPO_ROOT/source/vendor/bin/pint"
if [ -x "$PINT" ]; then
  "$PINT" "$ABS" >/dev/null 2>&1 || true
fi

exit 0
