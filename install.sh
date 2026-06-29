#!/usr/bin/env bash
# Cài bộ AI tooling (CLAUDE.md, AGENTS.md, docs/ai, .claude/commands+hooks,
#   .agent/workflows cho Antigravity) từ repo này vào một project,
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

# PAT Guard preflight check
SETTINGS_FILE="$TARGET/.claude/settings.local.json"
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q -E "ghp_|github_pat_" "$SETTINGS_FILE" 2>/dev/null; then
    echo "🚨 CẢNH BÁO: Phát hiện chuỗi giống Token (PAT) trong $SETTINGS_FILE!" >&2
    echo "Việc để lộ PAT trong settings.local.json là rủi ro bảo mật nghiêm trọng." >&2
    echo "Hãy revoke token hiện tại ngay lập tức, và sử dụng biến môi trường thay vì dán trực tiếp." >&2
    # Chặn tạm thời thay vì bắt nhập y/N vì môi trường CI/CD hoặc run script ko interactable
    # Để tiếp tục user phải xoá PAT khỏi file.
    echo "Vui lòng xóa token khỏi settings.local.json trước khi chạy cài đặt." >&2
    exit 1
  fi
fi

SRC="$(cd "$(dirname "$0")/payload" && pwd)"

echo "Cai tooling vao: $TARGET"
while IFS= read -r -d '' f; do
  rel="${f#./}"
  # Ngừng ship api-docs/ trong payload vì nó thuộc quyền sở hữu của repo project
  if [[ "$rel" == "api-docs"* ]]; then
    continue
  fi
  dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  
  # Idempotent backup
  if [ -f "$dest" ] && ! cmp -s "$SRC/$rel" "$dest"; then
    cp "$dest" "$dest.bak"
    echo "  ! Đã sao lưu file cũ: $rel.bak"
  fi
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

# Giu file AI ngoai git cua repo team (per-clone, khong dung .gitignore tracked).
# Sử dụng git rev-parse --git-path để an toàn cho worktree
if [ -d "$TARGET/.git" ] || [ -f "$TARGET/.git" ]; then
  EXCLUDE="$(git -C "$TARGET" rev-parse --git-path info/exclude 2>/dev/null || true)"
  if [ -n "$EXCLUDE" ]; then
    case "$EXCLUDE" in
      /*) ;;
      *) EXCLUDE="$TARGET/$EXCLUDE" ;;
    esac
    mkdir -p "$(dirname "$EXCLUDE")"
    for p in CLAUDE.md AGENTS.md .claude/ .agent/ .codex/ docs/ai/ Makefile.ai '*.bak'; do
      grep -qxF "$p" "$EXCLUDE" 2>/dev/null || printf '%s\n' "$p" >> "$EXCLUDE"
    done
    echo "  + da them file AI vao $EXCLUDE (giu ngoai git team)"
  fi
fi

echo
echo "Da cai: Claude (.claude/commands+hooks), Antigravity (.agent/workflows), Codex (~/.codex/prompts neu co)."

# Cấu hình cài đặt settings.local.json thông qua jq deep merge
echo "Đang cấu hình settings.local.json..."
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
  fi
  SNIPPET="$(dirname "$0")/hooks-snippet.json"
  if [ -f "$SNIPPET" ]; then
    jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$SNIPPET" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "  + Đã merge hooks vào $SETTINGS_FILE tự động."
  fi
else
  echo "⚠️ Không tìm thấy lệnh 'jq', vui lòng cài đặt 'jq' hoặc merge tay phần 'hooks' từ hooks-snippet.json vào $SETTINGS_FILE."
fi

if [ -f "$(dirname "$0")/VERSION" ]; then
  echo "Cài đặt thành công tooling phiên bản: $(cat "$(dirname "$0")/VERSION")"
fi
echo "Khởi động lại phiên làm việc AI để áp dụng thay đổi."
