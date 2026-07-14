#!/usr/bin/env bash
# Hook format/lint TOOL-AGNOSTIC (Codex / Antigravity / Claude đều dùng được).
# v1.4.1:
#   - Ưu tiên file path từ payload (thử nhiều field names).
#   - Với apply_patch, đọc danh sách file từ patch hunk nếu payload không có target_file.
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

extract_patch_paths() {
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "$INPUT" ] || return 0

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

# --- Thu thập file cần xử lý và ghi nhận ---

# Ưu tiên 1: lấy file từ payload hook (thử nhiều field names khác nhau)
TARGET_FILE=""
PATCH_FILES=""
if command -v jq >/dev/null 2>&1 && [ -n "$INPUT" ]; then
  TARGET_FILE="$(printf '%s' "$INPUT" | jq -r '
    .tool_args.TargetFile //
    .tool_input.file_path //
    .tool_input.target_file //
    .tool_input.targetFile //
    .tool_input.path //
    empty
  ' 2>/dev/null)"
  # Normalize nếu là absolute path; absolute ngoài repo sẽ bị skip.
  if [ -n "$TARGET_FILE" ]; then
    TARGET_FILE="$(normalize_to_rel "$TARGET_FILE")"
  fi

  PATCH_FILES="$(
    while IFS= read -r patch_file; do
      [ -z "$patch_file" ] && continue
      normalize_to_rel "$patch_file"
      printf '\n'
    done < <(extract_patch_paths)
  )"
  PATCH_FILES="$(printf '%s\n' "$PATCH_FILES" | sed '/^$/d' | sort -u)"
fi

collect_lint_files() {
  if [ -n "$PATCH_FILES" ]; then
    printf '%s\n' "$PATCH_FILES"
  elif [ -n "$TARGET_FILE" ]; then
    printf '%s\n' "$TARGET_FILE"
  else
    # Fallback: unstaged + untracked (BỎ staged)
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } 2>/dev/null | sort -u
  fi
}

# Ghi nhận TẤT CẢ các file php candidate vào manifest (cho strict mode)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in *.php) ;; *) continue ;; esac

  record_rc=0
  "$REPO_ROOT/.claude/scripts/record-touched-file.sh" "$REPO_ROOT" "$f" || record_rc=$?

  case "$record_rc" in
    0|10) ;;
    *)
      printf '[format-dirty] ⚠️ Unable to safely record touched file: %s\n' "$f" >&2
      exit 2
      ;;
  esac
done < <(collect_lint_files)

php_candidates="$(collect_lint_files | sed -n '/\.php$/p' | sort -u)"
[ -z "$php_candidates" ] && exit 0

# Kiểm tra Docker — KHÔNG fallback sang host
if ! has_make_target; then
  echo "[format-dirty] ⚠️ Makefile.ai không tồn tại — bỏ qua lint/format." >&2
  exit 0
fi

if ! container_up; then
  echo "[format-dirty] ⚠️ Container hrm-api không chạy — bỏ qua lint/format. Bật Docker rồi chạy tay." >&2
  exit 0
fi



# --- Lint & Format ---

# Lint/format các file .php. Chỉ format khi biết file từ payload target hoặc patch.
fail=0
format_allowed=0
if [ -n "$TARGET_FILE" ] || [ -n "$PATCH_FILES" ]; then
  format_allowed=1
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in *.php) ;; *) continue ;; esac
  file_exists "$f" || continue

  if ! OUT="$(AI_FILE="$f" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
    echo "[format-dirty] make ai-lint FAILED: $f" >&2
    printf '%s\n' "$OUT" >&2
    fail=1
    continue
  fi

  if [ "$format_allowed" = "1" ]; then
    if ! PINT_OUT="$(AI_FILE="$f" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint 2>&1)"; then
      echo "[format-dirty] make ai-pint FAILED: $f" >&2
      printf '%s\n' "$PINT_OUT" >&2
      fail=1
      continue
    fi

    if ! OUT2="$(AI_FILE="$f" make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint 2>&1)"; then
      echo "[format-dirty] make ai-lint FAILED after Pint: $f" >&2
      printf '%s\n' "$OUT2" >&2
      fail=1
    fi
  fi
done < <(printf '%s\n' "$php_candidates")

[ "$fail" = "1" ] && exit 2
exit 0
