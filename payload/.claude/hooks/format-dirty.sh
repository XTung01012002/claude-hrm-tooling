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

has_make_target() {
  [ -f "$REPO_ROOT/Makefile.ai" ]
}

container_up() {
  ( cd "$REPO_ROOT/docker/local" 2>/dev/null && docker compose exec -T hrm-api true >/dev/null 2>&1 )
}

collect_changed() {
  {
    git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM
    git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM --cached
    git -C "$REPO_ROOT" ls-files --others --exclude-standard
  } 2>/dev/null | sort -u
}

USE_AI_MAKE=0
if has_make_target ai-lint && has_make_target ai-pint && container_up; then
  USE_AI_MAKE=1
fi

cd "$SRC" || exit 0

# Lint các file .php đã đổi (unstaged + staged + untracked)
fail=0
host_warned=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in *.php) ;; *) continue ;; esac
  rel="${f#source/}"
  [ -f "$REPO_ROOT/$f" ] || continue
  if [ "$USE_AI_MAKE" = "1" ]; then
    if ! OUT="$(make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-lint FILE="$f" 2>&1)"; then
      echo "[format-dirty] make ai-lint FAILED: $f" >&2
      printf '%s\n' "$OUT" >&2
      fail=1
    fi
  else
    if [ "$host_warned" = "0" ]; then
      echo "[format-dirty] ⚠️ Makefile.ai/ai-* không có hoặc container down → verify trên HOST php, KHÔNG phải container 8.2.31 — kết quả KHÔNG đáng tin." >&2
      host_warned=1
    fi
    if ! php -l "$rel" >/dev/null 2>&1; then
      echo "[format-dirty] php -l FAILED: source/$rel" >&2
      php -l "$rel" >&2
      fail=1
    fi
  fi
done < <(collect_changed)

# Auto-format file dirty (không chặn)
if [ "$USE_AI_MAKE" = "1" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in *.php) ;; *) continue ;; esac
    [ -f "$REPO_ROOT/$f" ] || continue
    make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-pint FILE="$f" >/dev/null 2>&1 || true
  done < <(collect_changed)
else
  [ -x vendor/bin/pint ] && vendor/bin/pint --dirty >/dev/null 2>&1 || true
fi

[ "$fail" = "1" ] && exit 2
exit 0
