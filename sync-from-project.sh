#!/usr/bin/env bash
# Cap nhat payload/ tu mot project (nguoc voi install.sh) — dung khi tooling thay doi.
# Usage: ./sync-from-project.sh /duong-dan/toi/hrm-api [--apply]
# Mặc định là --dry-run (chỉ liệt kê, không thay đổi).
set -euo pipefail

SRC="${1:-}"
MODE="${2:---dry-run}"

[ -n "$SRC" ] || { echo "Usage: ./sync-from-project.sh /duong-dan/toi/project [--dry-run|--apply]" >&2; exit 1; }
case "$MODE" in
  --dry-run | --apply) ;;
  *)
    echo "Usage: ./sync-from-project.sh /duong-dan/toi/project [--dry-run|--apply]" >&2
    echo "❌ Option không hợp lệ: $MODE" >&2
    exit 2
    ;;
esac
SRC="$(cd "$SRC" 2>/dev/null && pwd)" || { echo "❌ Không tìm thấy thư mục: $1" >&2; exit 1; }
TOOLING_ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$TOOLING_ROOT/payload"

# --- Validation ---

# 1) Verify source là project HRM (phải có source/composer.json)
if [ ! -f "$SRC/source/composer.json" ]; then
  echo "❌ $SRC không giống project HRM (thiếu source/composer.json)." >&2
  echo "   Kiểm tra lại đường dẫn. Cần trỏ vào root project (chứa source/, docker/, ...)." >&2
  exit 1
fi

# 2) Chặn apply nếu tooling repo có uncommitted changes (tránh mất thay đổi chưa commit)
if [ "$MODE" = "--apply" ] && [ -n "$(git -C "$TOOLING_ROOT" status --porcelain 2>/dev/null)" ]; then
  echo "⚠️ Tooling repo có uncommitted changes." >&2
  echo "   Commit hoặc stash trước khi sync để tránh mất thay đổi." >&2
  echo "   Bỏ qua bước này bằng: git stash && $0 $*" >&2
  exit 1
fi

# --- Danh sách paths cần sync ---
paths="CLAUDE.md AGENTS.md Makefile.ai docs/ai .claude/commands .claude/hooks .claude/scripts .claude/settings.json .claude/skills .agent .codex"

if [ "$MODE" = "--apply" ]; then
  missing_paths=""
  for p in $paths; do
    [ -e "$SRC/$p" ] || missing_paths="${missing_paths}
$p"
  done
  if [ -n "$missing_paths" ]; then
    echo "❌ Source thiếu managed path; dừng sync để tránh payload stale:" >&2
    printf '%s\n' "$missing_paths" | sed '/^$/d; s/^/  - /' >&2
    exit 2
  fi
fi

echo "Source:  $SRC"
echo "Dest:    $DEST"
echo "Mode:    $MODE"
echo ""

if [ "$MODE" = "--dry-run" ]; then
  echo "=== DRY RUN (không thay đổi gì) ==="
  echo ""
fi

replace_path_from_stage() {
  src_path="$1"
  dest_path="$2"
  rel_path="$3"
  stage_root="$4"

  staged="$stage_root/value"
  tmp_dest="$dest_path.new.$$"
  backup_dest="$dest_path.old.$$"

  rm -rf "$staged" "$tmp_dest" "$backup_dest"
  mkdir -p "$(dirname "$staged")" "$(dirname "$dest_path")"
  cp -R "$src_path" "$staged"
  find "$staged" -name '*.bak*' -delete 2>/dev/null || true
  mv "$staged" "$tmp_dest"

  if [ -e "$dest_path" ]; then
    mv "$dest_path" "$backup_dest"
  fi

  if mv "$tmp_dest" "$dest_path"; then
    rm -rf "$backup_dest"
    return 0
  fi

  echo "❌ Không thể replace $rel_path — khôi phục bản cũ." >&2
  rm -rf "$tmp_dest"
  if [ -e "$backup_dest" ]; then
    mv "$backup_dest" "$dest_path"
  fi
  return 1
}

changed=0
for p in $paths; do
  if [ -e "$SRC/$p" ]; then
    if [ "$MODE" = "--dry-run" ]; then
      echo "  [dry-run] <= $p"
    else
      stage="$(mktemp -d "${TMPDIR:-/tmp}/hrm-tooling-sync.XXXXXX")"
      if ! replace_path_from_stage "$SRC/$p" "$DEST/$p" "$p" "$stage"; then
        rm -rf "$stage"
        exit 1
      fi
      rm -rf "$stage"
      echo "  <= $p"
    fi
    changed=$((changed + 1))
  else
    if [ "$MODE" = "--dry-run" ]; then
      echo "  [missing] $p (không tồn tại trong source)"
    fi
  fi
done

echo ""
if [ "$MODE" = "--dry-run" ]; then
  echo "Sẽ sync $changed path(s). Chạy lại với --apply để áp dụng:"
  echo "  $0 $1 --apply"
else
  echo "Đã cập nhật $changed path(s) trong payload/ từ: $SRC"
  echo ""
  echo "Kiểm tra thay đổi:"
  echo "  cd $TOOLING_ROOT && git diff --stat"
fi
