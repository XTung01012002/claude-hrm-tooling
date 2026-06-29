# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-06-29

### Added
- Bổ sung quy tắc "Tự kiểm tra sau khi sửa code" (soft-hook) vào `AGENTS.md`.
- Hỗ trợ `find-reuse` qua `docs/ai/prompts/find-reuse.md` làm nguồn chân lý, áp dụng cho cả Claude Code, Codex và Antigravity IDE.
- Cập nhật `.agent/hooks.json` với `PreToolUse` và `SessionStart` (parity với Codex).
- Bổ sung ma trận "Tính năng × tool theo THỰC TẾ" vào `HUONG-DAN-SU-DUNG.md`.

## [1.1.0] - 2026-06-29

### Added
- Thêm `Makefile.ai` proxy để chạy các lệnh verify (lint, pint, phpunit, artisan) qua `docker compose exec`. Không còn bị xanh giả khi verify trên host.
- PreToolUse guard `block-host-tools.sh` bắt AI sử dụng qua `Makefile.ai` để chặn verify trực tiếp bằng host PHP 8.5.
- Lệnh `/scaffold-feature` sinh khuôn 3 file feature chuẩn.
- Lệnh `/commit-message` hỗ trợ sinh commit tự động theo chuẩn.
- Bổ sung skill `find-reuse-candidates`.
- Bổ sung SessionStart hook `session-start.sh` kiểm tra Docker đang hoạt động để cảnh báo trước.
- Khóa .stop_hook_active để chặn lặp Stop hook vô tận.
- `settings.json` cho cấu hình project-wide, tách khỏi `settings.local.json`.
- Cảnh báo chống lộ PAT (github_pat_) trong `install.sh`.

### Changed
- Các script hook PHP (`php-lint.sh`, `format-dirty.sh`, `run-related-tests.sh`) đổi sang xài `make -f Makefile.ai`. Cảnh báo stderr to nếu rơi vào host fallback.
- `install.sh` tự động merge `hooks-snippet.json` vào `.claude/settings.local.json` qua `jq`. Hỗ trợ worktree `.git` xử lý `info/exclude`.
- Loại bỏ `api-docs` khỏi payload để tránh ghi đè repo dự án chính.
- `hooks-snippet.json` và `.codex/hooks.json` cập nhật Matcher sang `Edit|MultiEdit|Write|apply_patch`.
- Sync đồng nhất documentations `CLAUDE.md` và `AGENTS.md`.

## [1.0.0] - Initial Release
- Cấu trúc `PROJECT-CONVENTIONS.md` gốc
- Các template prompts review, refactor, generate-api-docs, generate-test.
- Hook cơ bản.
