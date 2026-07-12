#!/usr/bin/env bash
# SessionStart hook
# Kiểm tra sự sẵn sàng của Docker và Makefile.ai

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cat >/dev/null 2>&1 || true

# Xóa danh sách file đã chạm của phiên làm việc trước
rm -f "$REPO_ROOT/.claude/tmp/touched-files"

warn() {
  echo "⚠️ [Preflight] CẢNH BÁO: $1" >&2
}

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
