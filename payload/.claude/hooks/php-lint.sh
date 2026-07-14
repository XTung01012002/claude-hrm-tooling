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

candidate_files() {
  printf '%s' "$INPUT" | jq -r '
    [
      .tool_args.TargetFile?,
      .tool_input.file_path?,
      .tool_input.target_file?,
      .tool_input.targetFile?,
      .tool_input.path?
    ][]
    | select(type == "string" and length > 0)
  ' 2>/dev/null

  printf '%s' "$INPUT" | jq -r '
    [
      .tool_input.patch?,
      .tool_input.Patch?,
      .tool_args.patch?,
      .tool_args.Patch?,
      .tool_input.diff?,
      .tool_args.diff?
    ][]
    | select(type == "string")
  ' 2>/dev/null | sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p'
}

PHYSICAL_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || exit 0

lint_files=""
while IFS= read -r FILE; do
  [ -z "$FILE" ] && continue

  # Chỉ xử lý .php
  case "$FILE" in
    *.php) ;;
    *) continue ;;
  esac

  # Chuẩn hóa về absolute path từ repo root (path có thể tương đối kiểu source/src/...).
  case "$FILE" in
    /*) ABS="$FILE" ;;
    *)  ABS="$REPO_ROOT/$FILE" ;;
  esac

  PHYSICAL_PARENT="$(cd "$(dirname "$ABS")" 2>/dev/null && pwd -P)" || continue
  case "$PHYSICAL_PARENT/" in
    "$PHYSICAL_ROOT/"*) ;;
    *) continue ;;
  esac

  REL="${ABS#$REPO_ROOT/}"

  # Ghi nhận cả file PHP bị xóa để Stop hook thấy deletion trong strict verification.
  record_rc=0
  "$REPO_ROOT/.claude/scripts/record-touched-file.sh" "$REPO_ROOT" "$ABS" || record_rc=$?
  case "$record_rc" in
    0|10) ;;
    *)
      printf '[php-lint hook] ⚠️ Unable to safely record touched file: %s\n' "$ABS" >&2
      exit 2
      ;;
  esac

  [ -f "$ABS" ] || continue
  lint_files="${lint_files}
${REL}"
done < <(candidate_files | sort -u)

lint_files="$(printf '%s\n' "$lint_files" | sed '/^$/d' | sort -u)"
[ -z "$lint_files" ] && exit 0

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

runner_ready() {
  local conf_file="$REPO_ROOT/.claude/runner.local"
  [ -f "$conf_file" ] || return 1
  local content
  content="$(cat "$conf_file")"
  if [ -n "$content" ]; then
    [ -x "$content" ] || return 1
  else
    command -v php >/dev/null 2>&1 || return 1
  fi
  return 0
}

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  echo "[php-lint hook] ⚠️ Makefile.ai không tồn tại — bỏ qua lint/format." >&2
  echo "Danh sách file:" >&2
  printf '%s\n' "$lint_files" | sed 's/^/  - /' >&2
  echo "Chạy tay: AI_FILE=<file> make -f Makefile.ai ai-check" >&2
  exit 0
fi

if ! runner_ready && ! container_up; then
  echo "[php-lint hook] ⚠️ Container hrm-api không chạy và chưa cấu hình runner local — bỏ qua lint/format." >&2
  echo "Bật Docker hoặc tạo .claude/runner.local rồi chạy tay cho các file sau:" >&2
  printf '%s\n' "$lint_files" | sed 's/^/  - /' >&2
  exit 0
fi

while IFS= read -r REL; do
  [ -z "$REL" ] && continue

  # 1) Kiểm tra cú pháp — chặn nếu lỗi
  if ! OUT="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
    {
      echo "[php-lint hook] make ai-lint FAILED: $REL"
      printf '%s\n' "$OUT"
    } >&2
    exit 2
  fi

  # 2) Auto-format bằng Pint — chặn nếu fail để mọi đường sửa file có cùng chuẩn
  if ! PINT_OUT="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint 2>&1)"; then
    {
      echo "[php-lint hook] Pint format FAILED: $REL"
      printf '%s\n' "$PINT_OUT"
    } >&2
    exit 2
  fi

  # 3) Re-lint sau format (Pint có thể thay đổi syntax)
  if ! OUT2="$(AI_FILE="$REL" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
    {
      echo "[php-lint hook] ❌ Lint thất bại SAU KHI format: $REL"
      printf '%s\n' "$OUT2"
    } >&2
    exit 2
  fi
done < <(printf '%s\n' "$lint_files")

exit 0
