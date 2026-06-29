#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write).
# Lint (php -l) + auto-format (Pint) FILE vừa được Edit/Write nếu là .php.
# Đọc JSON hook từ stdin. Exit 0 = không chặn; exit 2 = chặn & báo ngược cho AI sửa.
#
# Tham chiếu: https://docs.anthropic.com/en/docs/claude-code/hooks
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Cần jq để parse payload hook — thiếu thì báo & bỏ qua (KHÔNG im lặng no-op).
command -v jq >/dev/null 2>&1 || { echo "[php-lint hook] jq không có — bỏ qua hook (cài jq để bật lint/format)" >&2; exit 0; }

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
REL="${ABS#$REPO_ROOT/}"

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

CU=0
if container_up; then
  CU=1
fi

# 1) Kiểm tra cú pháp — chặn nếu lỗi
if has_make_target ai-lint && [ "$CU" = "1" ]; then
  if ! OUT="$(make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint FILE="$REL" 2>&1)"; then
    {
      echo "[php-lint hook] make ai-lint FAILED:"
      printf '%s\n' "$OUT"
    } >&2
    exit 2
  fi
else
  echo "[php-lint hook] ⚠️ Makefile.ai/ai-* không có hoặc container down → verify trên HOST php, KHÔNG phải container 8.2.31 — kết quả KHÔNG đáng tin." >&2
  if ! php -l "$ABS" >/dev/null 2>&1; then
    {
      echo "[php-lint hook] php -l FAILED:"
      php -l "$ABS" 2>&1
    } >&2
    exit 2
  fi
fi

# 2) Auto-format bằng Pint (không chặn nếu Pint không có)
if has_make_target ai-pint && [ "$CU" = "1" ]; then
  make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint FILE="$REL" >/dev/null 2>&1 || true
else
  PINT="$REPO_ROOT/source/vendor/bin/pint"
  if [ -x "$PINT" ]; then
    "$PINT" "$ABS" >/dev/null 2>&1 || true
  fi
fi

exit 0
