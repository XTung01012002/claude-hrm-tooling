#!/usr/bin/env bash
# Cài bộ AI tooling (CLAUDE.md, AGENTS.md, docs/ai, .claude/commands+hooks,
#   .agents/workflows cho Antigravity) từ repo này vào một project,
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

umask 077

validate_parent_chain() {
  local path="$1"
  local base="${2:-}"
  
  if [ -n "$base" ]; then
    if [[ "$path" == "$base/"* ]]; then
      local rel="${path#$base/}"
      local current="$base"
      IFS='/' read -ra PARTS <<< "$rel"
      local max=$(( ${#PARTS[@]} - 1 ))
      for ((i=0; i<max; i++)); do
        local part="${PARTS[i]}"
        [ -z "$part" ] && continue
        current="${current%/}/$part"
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
    fi
  fi

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

validate_regular_file_target() {
  local path="$1"
  local label="$2"
  local base="${3:-}"
  
  validate_parent_chain "$path" "$base" || return 1

  if [ -L "$path" ]; then
    printf 'Unsafe %s symlink: %s\n' "$label" "$path" >&2
    return 1
  fi

  if [ -e "$path" ] && [ ! -f "$path" ]; then
    printf '%s path is not a regular file: %s\n' "$label" "$path" >&2
    return 1
  fi
}

# PAT Guard preflight check
SETTINGS_FILE="$TARGET/.claude/settings.local.json"
validate_regular_file_target "$SETTINGS_FILE" "settings.local.json" "$TARGET" || exit 1

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

for json_file in "$SNIPPET" "$SRC/.claude/settings.json" "$SRC/.agents/hooks.json" "$SRC/.codex/hooks.json"; do
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

NEW_MANAGED_PATHS=()
for rel in "${FILES_TO_INSTALL[@]}"; do
  NEW_MANAGED_PATHS+=("$rel")
done
NEW_MANAGED_PATHS+=(".agents/skills" ".claude/skills" ".claude/tooling-version" ".claude/tooling-manifest")

is_new_managed_path() {
  local needle="$1"
  local item
  for item in "${NEW_MANAGED_PATHS[@]}"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

backup_or_remove_owned_path() {
  local rel="$1"
  local dest="$TARGET/$rel"
  local stamp backup

  [ -e "$dest" ] || [ -L "$dest" ] || return 0

  stamp="$(date +%Y%m%d-%H%M%S).$$"
  backup="$dest.bak.$stamp"
  mkdir -p "$(dirname "$backup")"
  mv "$dest" "$backup"
  echo "  ! Đã sao lưu managed path cũ: ${backup#$TARGET/}"
}

cleanup_empty_parents() {
  local rel="$1"
  local dir="$TARGET/$(dirname "$rel")"

  while [ "$dir" != "$TARGET" ] && [ "$dir" != "/" ]; do
    rmdir "$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
}

prune_stale_managed_paths() {
  local manifest="$TARGET/.claude/tooling-manifest"
  local old_rel

  # Migration from older Antigravity layout. Backup instead of deleting to
  # preserve any local edits while removing the stale discovery path.
  if [ -e "$TARGET/.agent" ] || [ -L "$TARGET/.agent" ]; then
    backup_or_remove_owned_path ".agent"
  fi

  if [ -e "$manifest" ] || [ -L "$manifest" ]; then
    validate_regular_file_target "$manifest" "tooling manifest" "$TARGET" || exit 1
    while IFS= read -r old_rel; do
      [ -n "$old_rel" ] || continue
      case "$old_rel" in
        /* | *..*) continue ;;
      esac
      if ! is_new_managed_path "$old_rel"; then
        backup_or_remove_owned_path "$old_rel"
        cleanup_empty_parents "$old_rel"
      fi
    done < "$manifest"
  fi
}

write_tooling_manifest() {
  local manifest="$TARGET/.claude/tooling-manifest"
  local manifest_tmp

  validate_regular_file_target "$manifest" "tooling manifest" "$TARGET" || exit 1
  mkdir -p "$(dirname "$manifest")"
  manifest_tmp="$(mktemp "$TARGET/.claude/tooling-manifest.tmp.XXXXXX")"
  printf '%s\n' "${NEW_MANAGED_PATHS[@]}" | LC_ALL=C sort -u > "$manifest_tmp"
  chmod 600 "$manifest_tmp"
  mv "$manifest_tmp" "$manifest"
}

for rel in "${FILES_TO_INSTALL[@]}"; do
  dest="$TARGET/$rel"
  
  # 1. Chặn parent symlink escape và parent non-directory
  if ! validate_parent_chain "$dest" "$TARGET"; then
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
  if ! validate_parent_chain "$TARGET/$rel" "$TARGET"; then
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
    cp "$dest" "$backup"
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
  CODEX_PROMPTS_DIR="$HOME/.codex/prompts"
  validate_parent_chain "$CODEX_PROMPTS_DIR/.keep" "$HOME" || exit 1
  if [ -L "$CODEX_PROMPTS_DIR" ]; then
    echo "Unsafe Codex prompts symlink: $CODEX_PROMPTS_DIR" >&2
    exit 1
  fi
  if [ -e "$CODEX_PROMPTS_DIR" ] && [ ! -d "$CODEX_PROMPTS_DIR" ]; then
    echo "Codex prompts path is not a directory: $CODEX_PROMPTS_DIR" >&2
    exit 1
  fi
  mkdir -p "$CODEX_PROMPTS_DIR"

  current_codex_prompts="$(mktemp "${TMPDIR:-/tmp}/hrm-codex-prompts.XXXXXX")"
  for cmd in "$SRC"/.claude/commands/*.md; do
    [ -f "$cmd" ] || continue
    base="$(basename "$cmd")"
    prompt_dest="$CODEX_PROMPTS_DIR/hrm-${base}"
    validate_regular_file_target "$prompt_dest" "Codex prompt" "$HOME" || exit 1
    cp "$cmd" "$prompt_dest"
    printf '%s\n' "hrm-${base}" >> "$current_codex_prompts"
  done

  for old_prompt in "$CODEX_PROMPTS_DIR"/hrm-*.md; do
    [ -e "$old_prompt" ] || [ -L "$old_prompt" ] || continue
    old_base="$(basename "$old_prompt")"
    if ! grep -qxF "$old_base" "$current_codex_prompts" 2>/dev/null; then
      stamp="$(date +%Y%m%d-%H%M%S).$$"
      mv "$old_prompt" "$old_prompt.bak.$stamp"
      echo "  ! Đã sao lưu Codex prompt cũ: ${old_prompt#$CODEX_PROMPTS_DIR/}.bak.$stamp"
    fi
  done
  rm -f "$current_codex_prompts"
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
    for p in CLAUDE.md AGENTS.md .claude/ .codex/ docs/ai/ Makefile.ai '*.bak' '*.bak.*' '.claude/tooling-backups/' 'skills/' '.agents/hooks.json' '.agents/workflows/' '.agents/skills'; do
      grep -qxF "$p" "$EXCLUDE" 2>/dev/null || printf '%s\n' "$p" >> "$EXCLUDE"
    done
    echo "  + da them file AI vao $EXCLUDE (giu ngoai git team)"
  fi
fi

echo
echo "Da cai: Claude (.claude/commands+hooks), Antigravity (.agents/workflows+hooks), Codex (~/.codex/prompts neu co)."

# Cấu hình cài đặt settings.local.json thông qua jq deep merge (append + dedup arrays)
echo "Đang cấu hình settings.local.json..."
MERGE_OK=0
validate_regular_file_target "$SETTINGS_FILE" "settings.local.json" "$TARGET" || exit 1
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -e "$SETTINGS_FILE" ]; then
  settings_init_tmp="$(mktemp "$TARGET/.claude/settings.local.json.init.XXXXXX")"
  printf '{}\n' > "$settings_init_tmp"
  chmod 600 "$settings_init_tmp"
  mv "$settings_init_tmp" "$SETTINGS_FILE"
fi
if [ -f "$SNIPPET" ]; then
  settings_tmp="$(mktemp "$TARGET/.claude/settings.local.json.tmp.XXXXXX")"
  chmod 600 "$settings_tmp"
  # Deep merge: strip managed hook commands first, then append current snippet.
  if jq -n --slurpfile base "$SETTINGS_FILE" --slurpfile new "$SNIPPET" '
    def is_managed_hook:
      type == "object"
      and ((.command? // "") | type == "string")
      and ((.command? // "") | contains("/.claude/hooks/"));
    def strip_managed_hooks:
      if type == "array" then
        [ .[] | strip_managed_hooks | select(is_managed_hook | not) ]
      elif type == "object" then
        with_entries(.value |= strip_managed_hooks)
      else
        .
      end;
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
    ($base[0] | strip_managed_hooks) | deep_merge($new[0])
  ' > "$settings_tmp" && jq empty "$settings_tmp" >/dev/null; then
    mv "$settings_tmp" "$SETTINGS_FILE"
    echo "  + Đã merge hooks vào $SETTINGS_FILE (replace managed hooks + dedup, idempotent)."
    MERGE_OK=1
  else
    rm -f "$settings_tmp"
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

# Exit 1 nếu merge thất bại — caller biết cần kiểm tra. Chỉ prune sau khi cài
# và merge hooks thành công để tránh dọn file cũ trong một lần install dang dở.
[ "$MERGE_OK" = "1" ] || exit 1

prune_stale_managed_paths
write_tooling_manifest

echo "Khởi động lại phiên làm việc AI để áp dụng thay đổi."
