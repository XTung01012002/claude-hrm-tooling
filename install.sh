#!/usr/bin/env bash
# Cài bộ AI tooling (CLAUDE.md, AGENTS.md, docs/ai, .claude/commands+hooks,
#   .agent/workflows cho Antigravity) từ repo này vào một project,
#   + (tùy chọn) Codex global prompts vào ~/.codex/prompts.
#
# Usage: ./install.sh /duong-dan/toi/hrm-api
set -euo pipefail

TARGET=""
FORCE_OVERWRITE_TRACKED=0

for arg in "$@"; do
  case "$arg" in
    --force-overwrite-tracked)
      FORCE_OVERWRITE_TRACKED=1
      ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$arg"
      else
        echo "Lỗi: Quá nhiều đối số." >&2
        exit 1
      fi
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Usage: ./install.sh [--force-overwrite-tracked] /duong-dan/toi/project" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "Khong tim thay thu muc: $TARGET" >&2; exit 1; }

# Kiểm tra thư mục đích có phải là dự án HRM API hợp lệ không
if [ ! -f "$TARGET/source/composer.json" ] && [ ! -d "$TARGET/docker/local" ]; then
  echo "❌ LỖI: Thư mục đích ($TARGET) có vẻ không phải là dự án HRM API hợp lệ." >&2
  echo "  (Không tìm thấy source/composer.json hoặc docker/local/)" >&2
  exit 1
fi

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
SNIPPET="$(cd "$(dirname "$0")" && pwd)/hooks-snippet.json"

source "$(dirname "$0")/lib/managed-paths.sh"

# Preflight trước khi copy file để tránh cài đặt dở nếu merge hooks không thể chạy.
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ Không tìm thấy lệnh 'jq'. Cài jq trước khi chạy install.sh để merge hooks an toàn." >&2
  exit 1
fi

for json_file in "$SNIPPET" "$SRC/.claude/settings.json" "$SRC/.agent/hooks.json" "$SRC/.codex/hooks.json"; do
  if [ -f "$json_file" ]; then
    jq empty "$json_file" >/dev/null || {
      echo "❌ JSON không hợp lệ: $json_file" >&2
      exit 1
    }
  fi
done

if [ -f "$SETTINGS_FILE" ]; then
  jq empty "$SETTINGS_FILE" >/dev/null || {
    echo "❌ JSON không hợp lệ: $SETTINGS_FILE" >&2
    exit 1
  }
fi

echo "Cai tooling vao: $TARGET"

# --- Phase 1: Preflight Validation ---
TRACKED_CONFLICTS=0
SYMLINK_ESCAPES=0

validate_parent_chain() {
  local path="$1"
  local current=""
  IFS='/' read -ra PARTS <<< "$path"
  local max=$(( ${#PARTS[@]} - 1 ))
  for ((i=0; i<max; i++)); do
    local part="${PARTS[i]}"
    [ -z "$part" ] && continue
    current="$current/$part"
    if [ -L "$current" ]; then
      printf 'Parent component is a symlink: %s\n' "$current" >&2
      return 1
    fi
    if [ -e "$current" ] && [ ! -d "$current" ]; then
      printf 'Parent component is not a directory: %s\n' "$current" >&2
      return 1
    fi
  done
  return 0
}

# Gom danh sách các file vật lý từ MANAGED_PATHS để kiểm tra
FILES_TO_INSTALL=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  FILES_TO_INSTALL+=("$f")
done < <(
  for mp in "${MANAGED_PATHS[@]}"; do
    if [ -d "$SRC/$mp" ]; then
      cd "$SRC" && find "$mp" -type f
    elif [ -f "$SRC/$mp" ]; then
      echo "$mp"
    fi
  done
)

for rel in "${FILES_TO_INSTALL[@]}"; do
  dest="$TARGET/$rel"
  
  # 1. Chặn parent symlink escape và parent non-directory
  if ! validate_parent_chain "$dest"; then
    SYMLINK_ESCAPES=$((SYMLINK_ESCAPES + 1))
  elif [ -L "$dest" ]; then
    echo "❌ CẢNH BÁO: Phát hiện symlink tại đường dẫn đích (nguy cơ path traversal): $rel" >&2
    SYMLINK_ESCAPES=$((SYMLINK_ESCAPES + 1))
  fi

  # 2. Chặn overwrite file đã được track bởi Git của team
  if [ "$FORCE_OVERWRITE_TRACKED" != "1" ] && git -C "$TARGET" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
    echo "❌ CẢNH BÁO: Managed path đang được project track: $rel" >&2
    TRACKED_CONFLICTS=$((TRACKED_CONFLICTS + 1))
  fi
done

ALIAS_PATHS=(
  ".agents"
  ".agents/skills"
  ".claude"
  ".claude/skills"
)



for rel in "${ALIAS_PATHS[@]}"; do
  if ! validate_parent_chain "$TARGET/$rel"; then
    SYMLINK_ESCAPES=$((SYMLINK_ESCAPES + 1))
  fi
done

for alias_dir in ".agents" ".claude"; do
  alias_path="$alias_dir/skills"
  dest="$TARGET/$alias_path"
  
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" != "../skills" ]; then
      tracked_alias_entries="$(git -C "$TARGET" ls-files -- "$alias_path" 2>/dev/null)"
      if [ -n "$tracked_alias_entries" ] && [ "$FORCE_OVERWRITE_TRACKED" != "1" ]; then
        echo "❌ CẢNH BÁO: Alias $alias_path trỏ sai đích và đang được Git track. Dùng --force-overwrite-tracked để sửa." >&2
        TRACKED_CONFLICTS=$((TRACKED_CONFLICTS + 1))
      fi
    fi
  elif [ -d "$dest" ]; then
    tracked_alias_entries="$(git -C "$TARGET" ls-files -- "$alias_path" "$alias_path/**" 2>/dev/null)"
    if [ -n "$tracked_alias_entries" ] && [ "$FORCE_OVERWRITE_TRACKED" != "1" ]; then
      echo "❌ CẢNH BÁO: Thư mục $alias_path chứa file đang được Git track. Dùng --force-overwrite-tracked để chép đè." >&2
      TRACKED_CONFLICTS=$((TRACKED_CONFLICTS + 1))
    fi
  elif [ -e "$dest" ]; then
    tracked_alias_entries="$(git -C "$TARGET" ls-files -- "$alias_path" 2>/dev/null)"
    if [ -n "$tracked_alias_entries" ] && [ "$FORCE_OVERWRITE_TRACKED" != "1" ]; then
      echo "❌ CẢNH BÁO: File $alias_path đang được Git track. Dùng --force-overwrite-tracked để sửa." >&2
      TRACKED_CONFLICTS=$((TRACKED_CONFLICTS + 1))
    fi
  fi
done


if [ "$SYMLINK_ESCAPES" -gt 0 ]; then
  echo "❌ Cài đặt bị hủy vì phát hiện $SYMLINK_ESCAPES đường dẫn có nguy cơ symlink escape." >&2
  exit 1
fi

if [ "$TRACKED_CONFLICTS" -gt 0 ]; then
  echo "❌ Đã chặn cài đặt vì $TRACKED_CONFLICTS file đang được project track." >&2
  echo "Dùng --force-overwrite-tracked nếu thật sự muốn thay thế các file này." >&2
  exit 2
fi

# --- Phase 2: Copy Files ---
for rel in "${FILES_TO_INSTALL[@]}"; do
  dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  
  # Backup với timestamp
  if [ -f "$dest" ] && ! cmp -s "$SRC/$rel" "$dest"; then
    stamp="$(date +%Y%m%d-%H%M%S).$$"
    backup="$dest.bak.$stamp"
    cp -- "$dest" "$backup"
    echo "  ! Đã sao lưu file cũ: ${backup#$TARGET/}"
  fi
  cp "$SRC/$rel" "$dest"
  echo "  + $rel"
done

# Tạo symlink tự động cho aliases
ensure_skill_alias() {
  local alias_path="$1"
  local dest="$TARGET/$alias_path"
  local target_dir="$(dirname "$dest")"
  
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "../skills" ]; then
      return 0
    else
      rm -f "$dest"
    fi
  elif [ -e "$dest" ]; then
    local stamp="$(date +%Y%m%d-%H%M%S).$$"
    mv "$dest" "$dest.bak.$stamp"
    echo "  ! Đã sao lưu alias cũ thành $alias_path.bak.$stamp"
  fi
  
  mkdir -p "$target_dir"
  ln -s "../skills" "$dest"
  echo "  + Tạo symlink $alias_path -> ../skills"
}

ensure_skill_alias ".agents/skills"
ensure_skill_alias ".claude/skills"

chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$TARGET/.claude/scripts/"*.sh 2>/dev/null || true

# (Tùy chọn) Codex global slash commands: ~/.codex/prompts (dùng chung nội dung với .claude/commands, có namespace)
if [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex/prompts"
  for cmd in "$SRC"/.claude/commands/*.md; do
    [ -f "$cmd" ] || continue
    base="$(basename "$cmd")"
    cp "$cmd" "$HOME/.codex/prompts/hrm-${base}"
  done
  echo "  + ~/.codex/prompts/hrm-*.md (Codex slash commands: /prompts:hrm-review, /prompts:hrm-verify, ...)"
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
    for p in CLAUDE.md AGENTS.md .claude/ .agent/ .codex/ docs/ai/ Makefile.ai '*.bak' '*.bak.*' '.claude/tooling-backups/' 'skills/' '.agents/skills'; do
      grep -qxF "$p" "$EXCLUDE" 2>/dev/null || printf '%s\n' "$p" >> "$EXCLUDE"
    done
    echo "  + da them file AI vao $EXCLUDE (giu ngoai git team)"
  fi
fi

echo
echo "Da cai: Claude (.claude/commands+hooks), Antigravity (.agent/workflows), Codex (~/.codex/prompts neu co)."

# Cấu hình cài đặt settings.local.json thông qua jq deep merge (append + dedup arrays)
echo "Đang cấu hình settings.local.json..."
MERGE_OK=0
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi
if [ -f "$SNIPPET" ]; then
  # Deep merge: object keys merge đệ quy, arrays append + deduplicate (idempotent)
  if jq -n --slurpfile base "$SETTINGS_FILE" --slurpfile new "$SNIPPET" '
    def deep_merge($b):
      if type == "object" and ($b | type) == "object" then
        . as $a | reduce ($b | keys[]) as $k ($a;
          if has($k) then .[$k] = (.[$k] | deep_merge($b[$k]))
          else .[$k] = $b[$k] end
        )
      elif type == "array" and ($b | type) == "array" then
        [.[], $b[]] | unique_by(tojson)
      else $b
      end;
    $base[0] | deep_merge($new[0])
  ' > "${SETTINGS_FILE}.tmp"; then
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "  + Đã merge hooks vào $SETTINGS_FILE (arrays append + dedup, idempotent)."
    MERGE_OK=1
  else
    rm -f "${SETTINGS_FILE}.tmp"
    echo "❌ Merge hooks THẤT BẠI — kiểm tra lại $SETTINGS_FILE và chạy lại install.sh." >&2
  fi
fi

if [ -f "$(dirname "$0")/VERSION" ]; then
  mkdir -p "$TARGET/.claude"
  cp "$(dirname "$0")/VERSION" "$TARGET/.claude/tooling-version"
  VER="$(cat "$(dirname "$0")/VERSION")"
  if [ "$MERGE_OK" = "1" ]; then
    echo "Cài đặt thành công tooling phiên bản: $VER"
  else
    echo "Cài đặt tooling phiên bản $VER hoàn tất (⚠️ hooks chưa được merge — xem cảnh báo ở trên)." >&2
  fi
fi
echo "Khởi động lại phiên làm việc AI để áp dụng thay đổi."

# Exit 1 nếu merge thất bại — caller biết cần kiểm tra
[ "$MERGE_OK" = "1" ] || exit 1
