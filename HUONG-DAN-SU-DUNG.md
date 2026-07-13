# Hướng dẫn sử dụng — AI tooling HRM API

Bộ tooling giúp **vibe-coding** đúng convention, tự kiểm tra, tự sinh docs FE — dùng được trên **Claude Code · Codex · Antigravity**, cùng **một nguồn chân lý**.

Triết lý: (1) AI tự bám convention ngay từ đầu (đỡ review sửa nhiều vòng); (2) nội dung trung lập (`docs/ai/`) → AI nào cũng hiểu; (3) **bám code thật, cấm bịa**.

---

## A. Cấu trúc (1 nguồn chân lý + lớp tiện ích mỗi tool)

| Thành phần | Đường dẫn | Vai trò |
|---|---|---|
| **Nguồn chân lý** | `docs/ai/PROJECT-CONVENTIONS.md` | Toàn bộ rule (§0 cấm bịa, §1 reuse+DRY, §2 layering, §4 ORM, §8 multi-tenancy, §9 transaction/webhook, §10 list, §11 giữ behavior). Dùng cho MỌI AI. |
| **Prompt tái dùng** | `docs/ai/prompts/*.md` (13+ file) | Logic cho review / review-vs-plan / implement / test / api-docs / code-docs / diff-review / verify / refactor / feature / commit / reuse / task-breakdown |
| **Claude Code** | `CLAUDE.md` · `.claude/commands/*` · `.claude/hooks/*` + `.claude/settings.json` + `settings.local.json` | rule + lệnh + hook |
| **Codex** | `AGENTS.md` · `~/.codex/prompts/*` · `.codex/hooks.json` | rule + lệnh + hook |
| **Antigravity** | `AGENTS.md` · `.agents/workflows/*` · `.agents/hooks.json` | rule + lệnh + hook |

> `CLAUDE.md` (Claude) và `AGENTS.md` (Codex/Antigravity/Cursor) đều là **pointer mỏng** trỏ về `docs/ai/PROJECT-CONVENTIONS.md`. Sửa rule 1 chỗ → cả 3 cập nhật.

---

## B. Cách dùng hằng ngày (3 nền tảng)

**Bước chung:** mở đúng project (ở git root, nơi có `CLAUDE.md`/`AGENTS.md`) + **phiên mới** → cứ ra yêu cầu bình thường, AI đã tự nạp convention.

| Tính năng | Claude | Antigravity IDE | Codex ext |
|---|---|---|---|
| Rule tự nạp | CLAUDE.md ✅ | AGENTS.md ✅ | AGENTS.md ✅ |
| Slash/workflow | ✅ commands | ✅ workflows | ⚠️ prompts chập chờn → dựa AGENTS.md |
| Lint/format + test | ✅ hook thật | ❌ hook (dùng soft-run/AGENTS.md) | ⚠️ hook sau Trust (verify) |
| PreToolUse guard | ✅ | ❌ (soft trong AGENTS.md) | ⚠️ sau Trust (verify) |
| find-reuse | ✅ skill+cmd | ✅ workflow | ⚠️ AGENTS.md (+prompt nếu chạy) |

+ caveat: Codex extension cần **Trust** + verify `/hooks`; `~/.codex/prompts` có thể không hiện trong extension. Với Antigravity, kiểm tra workspace hooks trong `.agents/hooks.json` sau khi restart IDE.

Ý nghĩa lệnh:
- `/review` (soát diff theo checklist, verdict PASS/FAIL)
- `/review-vs-plan` (dùng AI/phiên độc lập đối chiếu implementation với Plan cuối)
- `/implement` (triển khai yêu cầu 10 bước — phân tích trước, code sau)
- `/scaffold-test` (sinh unit test Mockery, test matrix 14 nhóm)
- `/scaffold-feature` (sinh template 3 file feature)
- `/api-docs` (sinh docs FE contract-only + lưu ý cho FE)
- `/code-docs` (sinh tài liệu code nội bộ cho BE)
- `/diff-review` (review diff → verdict → branch + commit + PR)
- `/commit-message` (sinh commit nhanh, không review)
- `/verify` (adversarial verification — kiểm định cuối, chỉ kiểm không sửa)
- `/refactor` (review/refactor giữ behavior, mức độ 🔴🟡🟢)
- `/find-reuse` (tìm logic/interface tái sử dụng)
- `/task-breakdown` (bẻ việc/bóc task/estimate theo Size×Effort→Point, mỗi task ≤ 2 Point)

Với AI khác chưa có lệnh: dán thẳng `docs/ai/prompts/<x>.md` + nội dung cần xử lý.

---

## C. Setup trên MÁY MỚI (vd máy công ty)

### 1) Cài bộ tooling chung vào project
```bash
git clone https://github.com/XTung01012002/claude-hrm-tooling.git
cd claude-hrm-tooling
./install.sh /duong-dan/toi/hrm-api
```
`install.sh` copy vào project: `CLAUDE.md`, `AGENTS.md`, `Makefile.ai`, `docs/ai/`, `.claude/{commands,hooks,scripts,settings.json,skills}`, `.agents/{workflows,hooks.json}`, `.codex/hooks.json`; và copy `~/.codex/prompts/` nếu máy có `~/.codex`.

### 2) Một-lần cho từng nền tảng
- **Claude Code:** Script \`install.sh\` đã tự động merge hook vào \`.claude/settings.local.json\`. Bạn chỉ cần khởi động lại Claude Code.
- **Codex:** mở project bằng Codex → nó phát hiện `.codex/hooks.json` và hỏi *"N hooks need review"* → bấm **Trust all** (hoặc Review hooks để xem trước — hook gọi `make -f Makefile.ai ai-*` trong Docker). → khởi động lại phiên. (Prompts đã nằm ở `~/.codex/prompts`.)
- **Antigravity:** chỉ cần mở project (tự đọc `AGENTS.md` + `.agents/workflows/` + `.agents/hooks.json`). → khởi động lại phiên và kiểm tra hooks/workflows đã được load.

### 3) Verify nhanh
- Hỏi (không đính kèm file): *"feature mẫu chuẩn của dự án là gì?"* → phải trả lời `SaveZaloAccountStaff`.
- Gõ `/` xem có `review`/`review-vs-plan`/`implement`/`scaffold-test`/`api-docs`/`code-docs`/`diff-review`/`verify`/`refactor`/`commit-message`/`scaffold-feature`/`find-reuse`/`task-breakdown` không (13+ lệnh).
- (Claude/Codex) sửa thử 1 file `.php` format xấu → kiểm tra có tự `pint` không.

---

## D. Môi trường (RẤT QUAN TRỌNG — local ≠ Docker)
- Chạy thật trong **Docker container `hrm-api` (PHP 8.2.31)** thông qua script `Makefile.ai`. Host PHP mới hơn không được dùng làm chuẩn verify. Tooling đã có PreToolUse Guard chặn AI tự động verify trên host.
- Không chạy trực tiếp `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` trên host khi kiểm tra code. Nếu Docker down, hooks sẽ **bỏ qua lint/format/test** với cảnh báo — KHÔNG fallback sang host PHP.
- Lệnh chuẩn cho AI: `AI_FILE=source/... make -f Makefile.ai ai-lint`, `AI_FILE=source/... make -f Makefile.ai ai-pint`, `AI_FILE=source/... make -f Makefile.ai ai-check`, `AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test`, `make -f Makefile.ai ai-route-list`, `AI_ROUTE_PATH=api/v1/... make -f Makefile.ai ai-route-list`.
- Cài deps trong container: `make shell` → `composer install` → `make copy-vendor` (hoặc dùng target composer sẵn có trong `Makefile`).

---

## E. Khi tooling thay đổi → đồng bộ các máy
```bash
# Máy gốc:
cd /duong-dan/toi/claude-hrm-tooling
./sync-from-project.sh /duong-dan/toi/hrm-api    # copy file mới nhất từ project về payload/
git add -A && git commit -m "update tooling" && git push
# Máy khác:
git pull && ./install.sh /duong-dan/toi/hrm-api
```

---

## F. Bảo mật & Settings
- **`settings.json` vs `settings.local.json`**: Các rule chung cho project (allowlist các thư mục core) được lưu trong `.claude/settings.json` để chia sẻ giữa team. File `.claude/settings.local.json` chỉ chứa đường dẫn cá nhân (absolute) và bị gitignore.
- KHÔNG commit `.claude/settings.local.json`. File này có thể chứa PAT do rò rỉ session. Script `install.sh` đã có guard báo động nếu phát hiện PAT trong file này.
- KHÔNG dán Personal Access Token vào chat/commit. Lỡ lộ → https://github.com/settings/tokens **revoke ngay** + tạo token mới. Repo team có `gitleaks` pre-commit chặn rò rỉ — giữ nguyên.

---

## G. Tham chiếu nhanh
| Muốn… | Làm |
|---|---|
| AI hiểu convention | Tự nạp (`CLAUDE.md`/`AGENTS.md`); AI lạ: dán `docs/ai/PROJECT-CONVENTIONS.md` |
| Review code | `/review` |
| Đối chiếu code với Plan cuối | Mở phiên/AI độc lập rồi chạy `/review-vs-plan <plan-file> <range/file>` |
| Refactor giữ behavior | `/refactor` |
| Bẻ việc / bóc task / estimate | `/task-breakdown` |
| Sinh docs FE | `/api-docs` |
| Sinh test | `/scaffold-test <path>` |
| Chạy test | `AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test` |
| Format/lint | `AI_FILE=source/path/to/File.php make -f Makefile.ai ai-check` |
| Cài máy mới | `./install.sh /path/to/hrm-api` + (Claude) chỉ cần restart; (Codex) Trust |
| Đồng bộ thay đổi | `./sync-from-project.sh` → commit → push → (máy kia) pull + install |
