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

echo "Source:  $SRC"
echo "Dest:    $DEST"
echo "Mode:    $MODE"
echo ""

if [ "$MODE" = "--dry-run" ]; then
  echo "=== DRY RUN (không thay đổi gì) ==="
  echo ""
fi

changed=0
for p in $paths; do
  if [ -e "$SRC/$p" ]; then
    if [ "$MODE" = "--dry-run" ]; then
      echo "  [dry-run] <= $p"
    else
      mkdir -p "$DEST/$(dirname "$p")"
      rm -rf "$DEST/$p"
      cp -R "$SRC/$p" "$DEST/$p"
      # Xóa .bak files (tạo bởi installer) để tránh bị git add -A
      find "$DEST/$p" -name '*.bak*' -delete 2>/dev/null || true
      echo "  <= $p"
    fi
    changed=$((changed + 1))
  else
    echo "  [skip] $p (không tồn tại trong source)"
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
