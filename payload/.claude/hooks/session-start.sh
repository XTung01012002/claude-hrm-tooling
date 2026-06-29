#!/usr/bin/env bash
# SessionStart hook
# Kiểm tra sự sẵn sàng của Docker và Makefile.ai

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cat >/dev/null 2>&1 || true

warn() {
  echo "⚠️ [Preflight] CẢNH BÁO: $1" >&2
}

if [ ! -f "$REPO_ROOT/Makefile.ai" ]; then
  warn "File Makefile.ai chưa được tạo. Hãy đảm bảo bạn đã cài đặt bản cập nhật mới nhất của tooling."
else
  # Kiểm tra docker container
  if ! make -f "$REPO_ROOT/Makefile.ai" -C "$REPO_ROOT" ai-php CMD="-v" >/dev/null 2>&1; then
     warn "Không thể truy cập container \`hrm-api\` qua Docker Compose."
     warn "Code PHP sẽ fallback sang kiểm tra bằng máy host (có nguy cơ BÁO XANH GIẢ do sai lệch phiên bản PHP)."
     warn "👉 Hãy bật Docker container để AI tự kiểm tra được cú pháp chuẩn."
  fi
fi

exit 0
