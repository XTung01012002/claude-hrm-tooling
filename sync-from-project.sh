#!/usr/bin/env bash
# Cap nhat payload/ tu mot project (nguoc voi install.sh) — dung khi tooling thay doi.
# Usage: ./sync-from-project.sh /duong-dan/toi/hrm-api
set -euo pipefail

SRC="${1:-}"
[ -n "$SRC" ] || { echo "Usage: ./sync-from-project.sh /duong-dan/toi/project" >&2; exit 1; }
SRC="$(cd "$SRC" 2>/dev/null && pwd)" || { echo "Khong tim thay thu muc: $1" >&2; exit 1; }
DEST="$(cd "$(dirname "$0")" && pwd)/payload"

paths="CLAUDE.md AGENTS.md Makefile.ai docs/ai .claude/commands .claude/hooks .claude/settings.json .claude/skills .agent .codex"
for p in $paths; do
  if [ -e "$SRC/$p" ]; then
    mkdir -p "$DEST/$(dirname "$p")"
    rm -rf "$DEST/$p"
    cp -R "$SRC/$p" "$DEST/$p"
    # Xóa .bak files (tạo bởi installer) để tránh bị git add -A
    find "$DEST/$p" -name '*.bak' -delete 2>/dev/null || true
    echo "  <= $p"
  fi
done
echo "Da cap nhat payload/ tu: $SRC"
