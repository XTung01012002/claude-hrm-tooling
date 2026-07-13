#!/usr/bin/env bash
# SessionStart hook
# Kiểm tra sự sẵn sàng của Docker và Makefile.ai

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

warn() {
  echo "⚠️ [Preflight] CẢNH BÁO: $1" >&2
}

cat >/dev/null 2>&1 || true

# Xóa danh sách file đã chạm của phiên làm việc trước, nhưng chỉ sau khi
# xác minh .claude/tmp không đi qua symlink và vẫn nằm trong repository.
if ! . "$REPO_ROOT/.claude/scripts/validate-tooling-tmp.sh"; then
  warn "Không thể xác minh an toàn thư mục .claude/tmp; từ chối cleanup touched-files."
  exit 2
fi

TOUCHED_FILES="$REPO_ROOT/.claude/tmp/touched-files"
if [ -L "$TOUCHED_FILES" ]; then
  warn "touched-files là symlink; từ chối cleanup để tránh xóa ngoài repository."
  exit 2
fi

if [ -e "$TOUCHED_FILES" ] && [ ! -f "$TOUCHED_FILES" ]; then
  warn "touched-files không phải regular file; từ chối cleanup."
  exit 2
fi

rm -f -- "$TOUCHED_FILES"

if ! command -v jq >/dev/null 2>&1; then
  warn "Không tìm thấy lệnh 'jq'. Một số hooks bảo mật sẽ bị fail-open (bỏ qua kiểm tra)."
fi

if [ -f "$REPO_ROOT/.claude/tooling-version" ]; then
  VERSION=$(cat "$REPO_ROOT/.claude/tooling-version")
  echo "✅ Tooling version: $VERSION"
fi

if [ ! -f "$REPO_ROOT/Makefile.ai" ]; then
  warn "File Makefile.ai chưa được tạo. Hãy đảm bảo bạn đã cài đặt bản cập nhật mới nhất của tooling."
else
  # Kiểm tra docker container
  if ! make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-php-version >/dev/null 2>&1; then
     warn "Không thể truy cập container \`hrm-api\` qua Docker Compose."
     warn "Hooks lint/format/test sẽ BỎ QUA (KHÔNG fallback sang host PHP). Code sẽ không được tự kiểm tra."
     warn "👉 Hãy bật Docker container để AI tự kiểm tra được cú pháp chuẩn."
  fi
fi

exit 0
