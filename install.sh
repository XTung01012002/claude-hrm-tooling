#!/usr/bin/env bash
# Cài bộ AI tooling (CLAUDE.md, AGENTS.md, docs/ai, .claude/commands+hooks,
#   .agent/workflows cho Antigravity, api-docs) từ repo này vào một project,
#   + (tùy chọn) Codex global prompts vào ~/.codex/prompts.
#
# Usage: ./install.sh /duong-dan/toi/hrm-api
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: ./install.sh /duong-dan/toi/project" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "Khong tim thay thu muc: $1" >&2; exit 1; }

SRC="$(cd "$(dirname "$0")/payload" && pwd)"

echo "Cai tooling vao: $TARGET"
while IFS= read -r -d '' f; do
  rel="${f#./}"
  dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  cp "$SRC/$rel" "$dest"
  echo "  + $rel"
done < <(cd "$SRC" && find . -type f -print0)

chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

# (Tùy chọn) Codex global slash commands: ~/.codex/prompts (dùng chung nội dung với .claude/commands)
if [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex/prompts"
  cp "$SRC"/.claude/commands/*.md "$HOME/.codex/prompts/" 2>/dev/null \
    && echo "  + ~/.codex/prompts/ (Codex slash commands: /prompts:review, /prompts:refactor, ...)"
fi

echo
echo "Da cai: Claude (.claude/commands+hooks), Antigravity (.agent/workflows), Codex (~/.codex/prompts neu co)."
echo "Xong phan file."
echo "CON 1 BUOC THU CONG (settings.local.json khong dong bo: bi gitignore + chua path tuyet doi):"
echo "  1) Merge khoi \"hooks\" trong hooks-snippet.json vao: $TARGET/.claude/settings.local.json"
echo "     - Neu file chua co, tao moi voi noi dung cua hooks-snippet.json."
echo "     - Neu da co, chen them key \"hooks\" (dung ghi de cac key san co)."
echo "  2) Khoi dong lai phien Claude Code de hook co hieu luc."
