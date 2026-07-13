# Changelog

All notable changes to this project will be documented in this file.

## [1.7.2] - 2026-07-13

### Fixed
- Sửa lỗi crash `session-start.sh` khi `TOUCHED_FILES` unbound, đồng thời dọn sạch snapshot xử lý cũ và khôi phục các validation chống path traversal/symlink escape.
- Tối ưu `run-related-tests.sh` fallback: sử dụng marker `session-had-edits` thay vì hạ cấp mù quáng xuống advisory, chặn việc chạy test thừa thãi trên các thay đổi không do AI tạo ra trong phiên.
- Sửa `block-host-tools.sh` bắt sót edge case khi tool được gọi qua command substitution với trailing backtick.

## [1.7.1] - 2026-07-13

### Fixed
- Chuẩn hóa `/verify` theo file scope/base range/staged/untracked; nếu chỉ có attachment mà thiếu diff/base thì trả `BLOCKED_INSUFFICIENT_CONTEXT`.
- Làm verdict contract bất giao nhau và bắt buộc `Merge blocking: Yes | No` cho finding BLOCKER/IMPORTANT.
- Cho `apply_patch` đi qua Pint + lint lại giống các đường sửa file khác.
- Stop hook capture output test qua stderr, phát hiện deleted related tests và tránh stdout làm hỏng protocol hook.
- SessionStart cleanup `.claude/tmp` an toàn hơn với symlink.
- Host-PHP guard bắt thêm assignment/env/exec/nohup/php8.x và giảm false positive khi chỉ in chuỗi Makefile.ai.

### Changed
- `/commit-message` đọc thêm untracked files liên quan.
- `generate-api-docs` siết response envelope và sửa bảng Markdown request.
- `generate-code-docs` yêu cầu bằng chứng code/test cho phần giải thích "vì sao".
- Thêm `ai_workflows_reference.md` vào payload managed paths.

## [1.7.0] - 2026-07-13

### Added
- Thêm reviewer độc lập `/review-vs-plan` cho Claude Code, Codex và Antigravity: đối chiếu từng mục Plan cuối với code thật, tách thay đổi ngoài Plan khỏi finding chất lượng và kiểm tra bằng chứng test.

### Security
- Replace raw `CMD`/`ARGS` Makefile execution with fixed Docker targets and a validated `.claude/scripts/ai-docker.sh` wrapper.
- Remove Claude auto-allow wildcard permissions for Makefile targets that accept user input.
- Disable raw `ai-artisan-safe CMD=...` and `ai-artisan-unsafe CMD=...` targets.
- Move Makefile.ai file/test/path inputs to env-prefix form (`AI_FILE=... make ...`, `AI_TEST=... make ...`) to avoid GNU Make command-line variable expansion.
- Block old Makefile.ai command-line variables (`FILE=`, `TEST=`, `CMD=`, `ARGS=`, `ROUTE_PATH=`) in the Bash PreToolUse guard.
- Remove all Makefile.ai Bash auto-allow rules until Make env override hardening is proven safe.
- Hardcode Makefile.ai wrapper calls and pin `SHELL`/`.SHELLFLAGS` so `MAKEFLAGS=-e AI_RUN=...` cannot swap the runner.
- Block dangerous Make environment prefixes (`MAKEFLAGS`, `MFLAGS`, `GNUMAKEFLAGS`, `MAKEFILES`, `AI_RUN`, `SHELL`, `BASH_ENV`, `ENV`, `LD_PRELOAD`, `DYLD_*`) and host PHP tooling inside command substitution.
- Replace Makefile.ai guard parsing with exact command allow-list, blocking `--eval`, extra `-f`/`--file`, `env -S`, `-C`, pipes, redirects, and extra shell structure.
- Block host PHP tooling inside process substitution (`<(` and `>(`) before Docker/Make contexts are considered safe.

### Fixed
- Strict test hook now fails closed when related tests are found but Docker, Makefile.ai, or PHPUnit execution is unavailable.
- Strict test hook now rejects invalid `AI_TEST_MODE`, missing `source/`, and non-Git directories instead of passing silently.
- Strict test hook now fails closed when Git changed-file collection fails, and includes deleted/renamed PHP files in detection.
- `sync-from-project.sh` rejects invalid mode typos instead of treating them as apply mode.
- `sync-from-project.sh` now mirrors `.claude/scripts` with the rest of the Claude tooling.
- `sync-from-project.sh --dry-run` no longer fails just because the tooling repo has uncommitted changes.
- `sync-from-project.sh --apply` copies through staging and fails if a managed source path is missing, avoiding stale payload paths and delete-before-copy loss.
- `install.sh` validates `jq`/JSON before copying, logs the exact backup filename, excludes `*.bak.*`, and marks installed scripts executable.
- `/implement AUTO` no longer contradicts itself by always stopping after the plan.
- API docs and convention prompts now use fixed route-list targets instead of the removed raw artisan command.

### Changed
- Tách convention bền vững khỏi snapshot dễ thay đổi; thêm ngày và HRM source commit đã verify.
- Sửa mô tả Queue/Horizon theo từng environment và làm rõ queue connection Redis.
- Đồng bộ response envelope với exception renderer thật; bổ sung taxonomy exception và quy ước i18n.
- Bổ sung cache key/TTL/invalidation/store semantics; bỏ TODO `preserveRejectedStatus` khỏi source of truth.
- Đồng bộ `CLAUDE.md`, `AGENTS.md` và các prompt liên quan; runtime version chuyển thành snapshot cần re-verify.
- Làm rõ phạm vi tài liệu; Git branch/commit/PR workflow tiếp tục theo quy định team hoặc prompt riêng.

## [1.6.0] - 2026-07-12

### Security
- **Makefile.ai deny-list**: `ai-artisan` và `ai-php` giờ chặn lệnh nguy hiểm (migrate:fresh, migrate:reset, db:wipe, tinker, queue:clear, cache:clear, key:generate, schedule:run, horizon:terminate, php -r, eval). AI phải chạy tay trong container nếu thật sự cần.
- **settings.json thu hẹp**: bỏ wildcard `docker compose exec -T hrm-api *`, mọi lệnh phải đi qua `Makefile.ai` (đã có deny-list).

### Fixed
- **Hook test silent skip**: `run-related-tests.sh` giờ báo `⚠️ UNVERIFIED` kèm danh sách file khi không tìm thấy paired test, thay vì im lặng exit 0. AI không còn nhầm lẫn "không có test" với "test pass".
- **Pint error swallowed**: `php-lint.sh` giờ cảnh báo khi Pint fail và re-lint sau format để bắt syntax thay đổi.
- **sync-from-project.sh phá hủy**: giờ mặc định `--dry-run`, validate source (kiểm tra `source/composer.json`), chặn nếu tooling repo dirty. Phải truyền `--apply` rõ ràng.
- **install.sh backup ghi đè**: backup giờ có timestamp (`file.bak.20260712-213000`), không ghi đè backup cũ.
- **Codex prompts xung đột**: giờ có namespace `hrm-` prefix (`~/.codex/prompts/hrm-review.md`).

### Changed
- **`/implement` mode selection**: thêm 3 mode (STRICT mặc định / AUTO cho bug nhỏ / PLAN_ONLY). Bug fix rõ ràng không cần thêm vòng approve.
- **`/scaffold-test` test strategy profile**: thêm bước chọn Profile A (pure logic, 5 nhóm) / B (persistence, 9 nhóm) / C (event-driven, 14 nhóm) trước khi duyệt matrix. Mapper/DTO không phải duyệt 14 nhóm nữa.
- **`/verify` falsification**: đổi "assume at least one bug" thành "attempt to falsify; PASS is valid". Thêm Counterexample, Invariant, Evidence, Confidence cho mỗi finding.
- **`review.md` render fix**: sửa placeholder `<Cao>` bị GitHub render như HTML → dùng backtick.
- **Makefile.ai**: thêm `ai-pint-check` (--test), `ai-php-version`, `ai-route-list` target cụ thể.

## [1.5.0] - 2026-07-12

### Added
- **`/implement`** — Triển khai yêu cầu theo quy trình 10 bước (phân tích 7 bước trước → code sau). Prompt: `docs/ai/prompts/implement-requirement.md`.
- **`/verify`** — Adversarial Final Verification: AI kiểm định cuối cùng, chỉ kiểm không sửa, 12 chiều kiểm tra. Dùng cho workflow 2 AI review lẫn nhau. Prompt: `docs/ai/prompts/adversarial-verify.md`.
- **`/diff-review`** — Review diff trước → verdict PASS/FAIL → rồi mới sinh branch name + commit message + PR summary. Thay thế `/commit-message` cho workflow kỹ hơn. Prompt: `docs/ai/prompts/diff-review.md`.
- **`/code-docs`** — Sinh tài liệu code nội bộ cho developer BE (khác `api-docs/` cho FE). Prompt: `docs/ai/prompts/generate-code-docs.md`.
- Wrapper `.claude/commands/` và `.agent/workflows/` cho 4 prompt mới.

### Changed
- **`/scaffold-test`** viết lại hoàn toàn: bắt buộc tạo Test Matrix 14 nhóm (happy path, boundary, invalid, auth, state, duplicate, out-of-order, concurrency, transaction, external API, database, compatibility, side effects, time) trước khi viết test. Trước đây chỉ 3 nhóm.
- **`/review`** nâng cấp: thêm Verdict (PASS / PASS WITH CONCERNS / REQUEST CHANGES), mục "Missing tests" và "Questions/Assumptions" tách riêng.
- **`/api-docs`** nâng cấp: thêm mục "Lưu ý cho Frontend" bắt buộc (nullable fields, enum values, idempotency, reload, timezone, retry, side effects) + mục "Ví dụ gọi API" tùy chọn.
- Cập nhật `CLAUDE.md` và `AGENTS.md` — pointer cho 11+ slash commands.
- Cập nhật `HUONG-DAN-SU-DUNG.md` — bảng tham chiếu nhanh + ma trận tính năng mới.

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
