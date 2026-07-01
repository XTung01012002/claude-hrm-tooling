# Hướng dẫn sử dụng — AI tooling HRM API

Bộ tooling giúp **vibe-coding** đúng convention, tự kiểm tra, tự sinh docs FE — dùng được trên **Claude Code · Codex · Antigravity**, cùng **một nguồn chân lý**.

Triết lý: (1) AI tự bám convention ngay từ đầu (đỡ review sửa nhiều vòng); (2) nội dung trung lập (`docs/ai/`) → AI nào cũng hiểu; (3) **bám code thật, cấm bịa**.

---

## A. Cấu trúc (1 nguồn chân lý + lớp tiện ích mỗi tool)

| Thành phần | Đường dẫn | Vai trò |
|---|---|---|
| **Nguồn chân lý** | `docs/ai/PROJECT-CONVENTIONS.md` | Toàn bộ rule (§0 cấm bịa, §1 reuse+DRY, §2 layering, §4 ORM, §8 multi-tenancy, §9 transaction/webhook, §10 list, §11 giữ behavior). Dùng cho MỌI AI. |
| **Prompt tái dùng** | `docs/ai/prompts/{review,generate-api-docs,generate-test,refactor,generate-feature,commit-message,find-reuse,task-breakdown}.md` | Logic cho review / docs FE / test / refactor / feature / commit / reuse / bẻ việc-estimate |
| **Claude Code** | `CLAUDE.md` · `.claude/commands/*` · `.claude/hooks/*` + `.claude/settings.json` + `settings.local.json` | rule + lệnh + hook |
| **Codex** | `AGENTS.md` · `~/.codex/prompts/*` · `.codex/hooks.json` | rule + lệnh + hook |
| **Antigravity** | `AGENTS.md` · `.agent/workflows/*` (+ `.agent/hooks.json` cho bản CLI) | rule + lệnh + (soft-hook) |

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

+ caveat: Antigravity IDE không chạy hook → enforcement = AGENTS.md tự-tuân; Codex extension cần **Trust** + verify `/hooks`; `~/.codex/prompts` có thể không hiện trong extension.

Ý nghĩa lệnh: `/review` (soát diff theo checklist) · `/refactor` (review/refactor giữ behavior, mức 🔴🟡🟢) · `/api-docs` (sinh docs FE `api-docs/<Module>/<Endpoint>.md`) · `/scaffold-test` (sinh unit test Mockery) · `/task-breakdown` (bẻ việc/bóc task/estimate theo Size×Effort→Point, mỗi task ≤ 2 Point).
Với AI khác chưa có lệnh: dán thẳng `docs/ai/prompts/<x>.md` + nội dung cần xử lý.

---

## C. Setup trên MÁY MỚI (vd máy công ty)

### 1) Cài bộ tooling chung vào project
```bash
git clone https://github.com/XTung01012002/claude-hrm-tooling.git
cd claude-hrm-tooling
./install.sh /duong-dan/toi/hrm-api
```
`install.sh` copy vào project: `CLAUDE.md`, `AGENTS.md`, `Makefile.ai`, `docs/ai/`, `.claude/{commands,hooks,settings.json,skills}`, `.agent/{workflows,hooks.json}`, `.codex/hooks.json`; và copy `~/.codex/prompts/` nếu máy có `~/.codex`.

### 2) Một-lần cho từng nền tảng
- **Claude Code:** Script \`install.sh\` đã tự động merge hook vào \`.claude/settings.local.json\`. Bạn chỉ cần khởi động lại Claude Code.
- **Codex:** mở project bằng Codex → nó phát hiện `.codex/hooks.json` và hỏi *"N hooks need review"* → bấm **Trust all** (hoặc Review hooks để xem trước — hook gọi `make -f Makefile.ai ai-*` trong Docker). → khởi động lại phiên. (Prompts đã nằm ở `~/.codex/prompts`.)
- **Antigravity:** chỉ cần mở project (tự đọc `AGENTS.md` + `.agent/workflows/`). → khởi động lại phiên. *(Bản IDE không chạy `.agent/hooks.json` → format dựa vào soft-hook trong `AGENTS.md`; bản CLI thì hook chạy thật.)*

### 3) Verify nhanh
- Hỏi (không đính kèm file): *"feature mẫu chuẩn của dự án là gì?"* → phải trả lời `SaveZaloAccountStaff`.
- Gõ `/` xem có `review`/`refactor`/`api-docs`/`scaffold-test`/`scaffold-feature`/`commit-message`/`find-reuse`/`task-breakdown` không.
- (Claude/Codex) sửa thử 1 file `.php` format xấu → kiểm tra có tự `pint` không.

---

## D. Môi trường (RẤT QUAN TRỌNG — local ≠ Docker)
- Chạy thật trong **Docker container `hrm-api` (PHP 8.2.31)** thông qua script `Makefile.ai`. Host PHP mới hơn không được dùng làm chuẩn verify. Tooling đã có PreToolUse Guard chặn AI tự động verify trên host.
- Không chạy trực tiếp `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` trên host khi kiểm tra code. Nếu Docker down, hooks sẽ **bỏ qua lint/format/test** với cảnh báo — KHÔNG fallback sang host PHP.
- Lệnh chuẩn cho AI: `make -f Makefile.ai ai-lint FILE=source/...`, `make -f Makefile.ai ai-pint FILE=source/...`, `make -f Makefile.ai ai-check FILE=source/...`, `make -f Makefile.ai ai-test TEST=tests/Unit/XTest.php`, `make -f Makefile.ai ai-artisan CMD="route:list"`.
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
| Refactor giữ behavior | `/refactor` |
| Bẻ việc / bóc task / estimate | `/task-breakdown` |
| Sinh docs FE | `/api-docs` |
| Sinh test | `/scaffold-test <path>` |
| Chạy test | `make -f Makefile.ai ai-test TEST=tests/Unit/XTest.php` |
| Format/lint | `make -f Makefile.ai ai-check FILE=source/path/to/File.php` |
| Cài máy mới | `./install.sh /path/to/hrm-api` + (Claude) chỉ cần restart; (Codex) Trust |
| Đồng bộ thay đổi | `./sync-from-project.sh` → commit → push → (máy kia) pull + install |
