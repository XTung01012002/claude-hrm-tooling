#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write).
# Lint (php -l) + auto-format (Pint) FILE vừa được Edit/Write nếu là .php.
# Đọc JSON hook từ stdin. Exit 0 = không chặn; exit 2 = chặn & báo ngược cho AI sửa.
#
# v1.4: bỏ host fallback — nếu Docker down thì skip rõ ràng (exit 0 + cảnh báo) thay vì verify bằng host PHP.
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
case "$FILE" in
  /*) ABS="$FILE" ;;
  *)  ABS="$REPO_ROOT/$FILE" ;;
esac
[ -f "$ABS" ] || exit 0
REL="${ABS#$REPO_ROOT/}"

# Ghi nhận file đã chạm vào file tạm của session
TOUCHED_FILES="$REPO_ROOT/.claude/tmp/touched-files"
mkdir -p "$(dirname "$TOUCHED_FILES")"
case "$REL" in
  source/*) echo "$REL" >> "$TOUCHED_FILES" ;;
esac

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  echo "[php-lint hook] ⚠️ Makefile.ai không tồn tại — bỏ qua lint/format. Chạy tay: AI_FILE=$REL make -f Makefile.ai ai-check" >&2
  exit 0
fi

if ! container_up; then
  echo "[php-lint hook] ⚠️ Container hrm-api không chạy — bỏ qua lint/format. Bật Docker rồi chạy tay: AI_FILE=$REL make -f Makefile.ai ai-check" >&2
  exit 0
fi

# 1) Kiểm tra cú pháp — chặn nếu lỗi
if ! OUT="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
  {
    echo "[php-lint hook] make ai-lint FAILED:"
    printf '%s\n' "$OUT"
  } >&2
  exit 2
fi

# 2) Auto-format bằng Pint — cảnh báo nếu fail (không chặn vì format là best-effort)
if ! PINT_OUT="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint 2>&1)"; then
  {
    echo "[php-lint hook] ⚠️ Pint format thất bại — file có thể chưa được format:"
    printf '%s\n' "$PINT_OUT" | tail -5
  } >&2
fi

# 3) Re-lint sau format (Pint có thể thay đổi syntax)
if ! OUT2="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
  {
    echo "[php-lint hook] ❌ Lint thất bại SAU KHI format:"
    printf '%s\n' "$OUT2"
  } >&2
  exit 2
fi

exit 0
