#!/usr/bin/env bash
# Hook format/lint TOOL-AGNOSTIC (Codex / Antigravity / Claude đều dùng được).
# v1.4.1:
#   - Ưu tiên file path từ payload (thử nhiều field names).
#   - Fallback: unstaged + untracked (để bắt file mới tạo), nhưng BỎ staged.
#   - Sửa path normalization: absolute path không bị ghép sai.
#   - Bỏ host fallback — Docker down thì skip rõ ràng.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/source"

# Đọc stdin (payload hook)
INPUT="$(cat 2>/dev/null || true)"

[ -d "$SRC" ] || exit 0

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  echo "[format-dirty] ⚠️ Makefile.ai không tồn tại — bỏ qua lint/format." >&2
  exit 0
fi

if ! container_up; then
  echo "[format-dirty] ⚠️ Container hrm-api không chạy — bỏ qua lint/format. Bật Docker rồi chạy tay." >&2
  exit 0
fi

# --- Normalize path: absolute → relative to REPO_ROOT ---
normalize_to_rel() {
  local f="$1"
  case "$f" in
    "$REPO_ROOT"/*) printf '%s' "${f#$REPO_ROOT/}" ;;
    /*) return ;;  # absolute ngoài repo — reject (không in gì)
    *) printf '%s' "$f" ;;
  esac
}

file_exists() {
  local f="$1"
  case "$f" in
    /*) return 1 ;;  # reject absolute path — phải normalize trước
    *)  [ -f "$REPO_ROOT/$f" ] ;;
  esac
}

# --- Thu thập file cần xử lý ---

# Ưu tiên 1: lấy file từ payload hook (thử nhiều field names khác nhau)
TARGET_FILE=""
if command -v jq >/dev/null 2>&1 && [ -n "$INPUT" ]; then
  TARGET_FILE="$(printf '%s' "$INPUT" | jq -r '
    .tool_input.file_path //
    .tool_input.target_file //
    .tool_input.targetFile //
    .tool_input.path //
    empty
  ' 2>/dev/null)"
  # Normalize nếu là absolute path
  if [ -n "$TARGET_FILE" ]; then
    TARGET_FILE="$(normalize_to_rel "$TARGET_FILE")"
  fi
fi

collect_lint_files() {
  if [ -n "$TARGET_FILE" ]; then
    printf '%s\n' "$TARGET_FILE"
  else
    # Fallback: unstaged + untracked (BỎ staged)
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } 2>/dev/null | sort -u
  fi
}

# Lint các file .php
fail=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in *.php) ;; *) continue ;; esac
  file_exists "$f" || continue
  if ! OUT="$(make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint FILE="$f" 2>&1)"; then
    echo "[format-dirty] make ai-lint FAILED: $f" >&2
    printf '%s\n' "$OUT" >&2
    fail=1
  fi
done < <(collect_lint_files)

# Auto-format: CHỈ khi biết chính xác file AI sửa (có TARGET_FILE)
# Không có TARGET_FILE → KHÔNG format để tránh sửa file ngoài phạm vi AI
if [ -n "$TARGET_FILE" ]; then
  case "$TARGET_FILE" in *.php)
    file_exists "$TARGET_FILE" && \
      make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint FILE="$TARGET_FILE" >/dev/null 2>&1 || true
  ;; esac
fi

[ "$fail" = "1" ] && exit 2
exit 0
