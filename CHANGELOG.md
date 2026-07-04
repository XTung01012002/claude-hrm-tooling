# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Thêm reviewer độc lập `/review-vs-plan` cho Claude Code, Codex và Antigravity: đối chiếu từng mục Plan cuối với code thật, tách thay đổi ngoài Plan khỏi finding chất lượng và kiểm tra bằng chứng test.

### Changed
- Tách convention bền vững khỏi snapshot dễ thay đổi; thêm ngày và HRM source commit đã verify.
- Sửa mô tả Queue/Horizon theo từng environment và làm rõ queue connection Redis.
- Đồng bộ response envelope với exception renderer thật; bổ sung taxonomy exception và quy ước i18n.
- Bổ sung cache key/TTL/invalidation/store semantics; bỏ TODO `preserveRejectedStatus` khỏi source of truth.
- Đồng bộ `CLAUDE.md`, `AGENTS.md` và các prompt liên quan; runtime version chuyển thành snapshot cần re-verify.
- Làm rõ phạm vi tài liệu; Git branch/commit/PR workflow tiếp tục theo quy định team hoặc prompt riêng.

## [1.4.0] - 2026-07-01

### Fixed
- **Lệnh sai trong source of truth**: sửa 8 chỗ `make ai-*` → `make -f Makefile.ai ai-*` trong `PROJECT-CONVENTIONS.md` §7, `generate-test.md`, `generate-api-docs.md`. Trước đó pointer files (`CLAUDE.md`/`AGENTS.md`) đã đúng nhưng nguồn chân lý lại sai.
- **PreToolUse guard false-positive + bypass**: viết lại — chỉ match ở vị trí command (sau `; & | (` hoặc đầu dòng), bắt absolute path (`/usr/bin/php`), bắt subshell (`bash -lc 'php -v'`). `rg php source/` / `echo php` / `git grep composer` không còn bị chặn nhầm.
- **Host fallback mâu thuẫn convention**: bỏ fallback sang host PHP ở `php-lint.sh`, `format-dirty.sh`, `run-related-tests.sh`. Docker down → hook skip rõ ràng với message hướng dẫn chạy tay. Cập nhật cảnh báo `session-start.sh` và `HUONG-DAN-SU-DUNG.md` cho khớp.
- **format-dirty.sh sửa file ngoài phạm vi**: ưu tiên file từ hook payload (thử nhiều field names), fallback collect unstaged + untracked mới tạo (bỏ staged). Sửa bug absolute path bị ghép sai (`$REPO_ROOT/$abs` → normalize).
- **install.sh `jq` merge không idempotent**: đổi sang `unique_by(tojson)` — chạy installer nhiều lần không duplicate hooks.
- **install.sh false-success + exit code**: merge fail → in lỗi + exit 1 (trước đây exit 0 và in "Cài đặt thành công").
- **sync-from-project.sh**: thêm 3 path (`Makefile.ai`, `.claude/settings.json`, `.claude/skills`), lọc `*.bak` sau khi copy.
- **HUONG-DAN-SU-DUNG.md**: bỏ mention `api-docs/`, cập nhật danh sách files install.sh copy, sửa mô tả Docker-down behavior.
- **Makefile.ai**: thêm `.PHONY`, thêm `--do-not-cache-result` cho `ai-test` (tránh permission denied trên `.phpunit.result.cache`).
- **php-lint.sh**: sửa comment "fail rõ ràng" → "skip rõ ràng" cho đúng behavior (exit 0 + cảnh báo).
- **.gitignore**: thêm `*.bak` tránh backup files bị git track.

### Known Issues
- Codex global prompts (`~/.codex/prompts/`) dùng cơ chế deprecated. Cần migrate sang `.agents/skills/` trong phiên bản sau.

## [1.3.0] - 2026-06-30

### Added
- Lệnh `/task-breakdown` (bẻ việc / bóc task / estimate) cho cả **Claude Code, Codex và Antigravity IDE**: nguồn chân lý `docs/ai/prompts/task-breakdown.md`, wrapper `.claude/commands/task-breakdown.md` + `.agent/workflows/task-breakdown.md` (Codex nhận qua `~/.codex/prompts` khi chạy `install.sh`).
- Rule estimate: chia task theo Technical Boundary, ma trận Size×Effort→Point (trần **2 Point/task**, bắt buộc tách nếu vượt), reuse-first và chống cộng trùng point — gồm cả chống cộng trùng across nhiều file trong cùng một phiên bóc gộp (§6.5).

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
