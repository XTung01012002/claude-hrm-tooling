#!/usr/bin/env bash
# Hook format/lint TOOL-AGNOSTIC (Codex / Antigravity / Claude đều dùng được).
# KHÔNG phụ thuộc payload hook (Codex apply_patch không có field file_path sạch) —
# thay vào đó format + lint các file PHP đang "dirty" theo git.
#   - php -l từng file .php đã đổi (chặn nếu sai cú pháp → exit 2)
#   - vendor/bin/pint --dirty (auto-format file chưa commit)
# Tự định vị repo qua vị trí script nên chạy được từ mọi cwd.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/source"
cat >/dev/null 2>&1 || true   # drain stdin nếu hook có truyền (không dùng)

[ -d "$SRC" ] || exit 0
cd "$SRC" || exit 0

# Lint các file .php đã đổi (unstaged + staged + untracked)
fail=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in *.php) ;; *) continue ;; esac
  rel="${f#source/}"
  [ -f "$rel" ] || continue
  if ! php -l "$rel" >/dev/null 2>&1; then
    echo "[format-dirty] php -l FAILED: source/$rel" >&2
    php -l "$rel" >&2
    fail=1
  fi
done < <( { git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM;
            git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM --cached;
            git -C "$REPO_ROOT" ls-files --others --exclude-standard; } 2>/dev/null | sort -u )

# Auto-format file dirty (không chặn)
[ -x vendor/bin/pint ] && vendor/bin/pint --dirty >/dev/null 2>&1 || true

[ "$fail" = "1" ] && exit 2
exit 0
