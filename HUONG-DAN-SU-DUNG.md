# Hướng dẫn sử dụng — AI tooling HRM API

Bộ tooling giúp **vibe-coding** đúng convention, tự kiểm tra, tự sinh docs FE — dùng được trên **Claude Code · Codex · Antigravity**, cùng **một nguồn chân lý**.

Triết lý: (1) AI tự bám convention ngay từ đầu (đỡ review sửa nhiều vòng); (2) nội dung trung lập (`docs/ai/`) → AI nào cũng hiểu; (3) **bám code thật, cấm bịa**.

---

## A. Cấu trúc (1 nguồn chân lý + lớp tiện ích mỗi tool)

| Thành phần | Đường dẫn | Vai trò |
|---|---|---|
| **Nguồn chân lý** | `docs/ai/PROJECT-CONVENTIONS.md` | Toàn bộ rule (§0 cấm bịa, §1 reuse+DRY, §2 layering, §4 ORM, §8 multi-tenancy, §9 transaction/webhook, §10 list, §11 giữ behavior). Dùng cho MỌI AI. |
| **Prompt tái dùng** | `docs/ai/prompts/{review,generate-api-docs,generate-test,refactor}.md` | Logic cho review / docs FE / test / refactor |
| **Claude Code** | `CLAUDE.md` · `.claude/commands/*` · `.claude/hooks/*` + `settings.local.json` | rule + lệnh + hook |
| **Codex** | `AGENTS.md` · `~/.codex/prompts/*` · `.codex/hooks.json` | rule + lệnh + hook |
| **Antigravity** | `AGENTS.md` · `.agent/workflows/*` (+ `.agent/hooks.json` cho bản CLI) | rule + lệnh + (soft-hook) |

> `CLAUDE.md` (Claude) và `AGENTS.md` (Codex/Antigravity/Cursor) đều là **pointer mỏng** trỏ về `docs/ai/PROJECT-CONVENTIONS.md`. Sửa rule 1 chỗ → cả 3 cập nhật.

---

## B. Cách dùng hằng ngày (3 nền tảng)

**Bước chung:** mở đúng project (ở git root, nơi có `CLAUDE.md`/`AGENTS.md`) + **phiên mới** → cứ ra yêu cầu bình thường, AI đã tự nạp convention.

| Nền tảng | Rule tự nạp | Lệnh tắt | Auto format/test sau khi sửa |
|---|---|---|---|
| **Claude Code** | `CLAUDE.md` (tự) | `/review` `/api-docs` `/scaffold-test` `/refactor` | ✅ Hook thật (php -l + pint mỗi lần sửa; phpunit cuối lượt) |
| **Codex** | `AGENTS.md` (tự) | gõ `/` → chọn `review`/`refactor`/`api-docs`/`scaffold-test` (hoặc `/prompts:review`…) | ✅ Hook thật (sau khi **Trust** — xem mục C) |
| **Antigravity** | `AGENTS.md` (tự) | gõ `/` → `review`/`refactor`/`api-docs`/`scaffold-test` (workflows) | ⚙️ Soft-hook: AI **tự chạy** `pint` theo lệnh trong `AGENTS.md` |

Ý nghĩa lệnh: `/review` (soát diff theo checklist) · `/refactor` (review/refactor giữ behavior, mức 🔴🟡🟢) · `/api-docs` (sinh docs FE `api-docs/<Module>/<Endpoint>.md`) · `/scaffold-test` (sinh unit test Mockery).
Với AI khác chưa có lệnh: dán thẳng `docs/ai/prompts/<x>.md` + nội dung cần xử lý.

---

## C. Setup trên MÁY MỚI (vd máy công ty)

### 1) Cài bộ tooling chung vào project
```bash
git clone https://github.com/XTung01012002/claude-hrm-tooling.git
cd claude-hrm-tooling
./install.sh /duong-dan/toi/hrm-api
```
`install.sh` copy vào project: `CLAUDE.md`, `AGENTS.md`, `docs/ai/`, `.claude/{commands,hooks}`, `.agent/{workflows,hooks.json}`, `.codex/hooks.json`, `api-docs/`; và copy `~/.codex/prompts/` nếu máy có `~/.codex`.

### 2) Một-lần cho từng nền tảng
- **Claude Code:** mở `hooks-snippet.json` (trong repo tooling) → dán khối `"hooks"` vào `<project>/.claude/settings.local.json` (chưa có thì tạo mới; có rồi thì chèn thêm key `hooks`). → khởi động lại Claude Code.
- **Codex:** mở project bằng Codex → nó phát hiện `.codex/hooks.json` và hỏi *"N hooks need review"* → bấm **Trust all** (hoặc Review hooks để xem trước — chỉ chạy pint/php -l/phpunit). → khởi động lại phiên. (Prompts đã nằm ở `~/.codex/prompts`.)
- **Antigravity:** chỉ cần mở project (tự đọc `AGENTS.md` + `.agent/workflows/`). → khởi động lại phiên. *(Bản IDE không chạy `.agent/hooks.json` → format dựa vào soft-hook trong `AGENTS.md`; bản CLI thì hook chạy thật.)*

### 3) Verify nhanh
- Hỏi (không đính kèm file): *"feature mẫu chuẩn của dự án là gì?"* → phải trả lời `SaveZaloAccountStaff`.
- Gõ `/` xem có `review`/`refactor`/`api-docs`/`scaffold-test` không.
- (Claude/Codex) sửa thử 1 file `.php` format xấu → kiểm tra có tự `pint` không.

---

## D. Môi trường (RẤT QUAN TRỌNG — local ≠ Docker)
- Chạy thật trong **Docker (PHP 8.2.31)**. Local PHP mới hơn → `composer install`/`php artisan` local **FAIL**. Cài deps trong container: `make shell` → `composer install` → `make copy-vendor`.
- Test (local OK): `cd source && vendor/bin/phpunit tests/Unit/XTest.php`.
- Format: `cd source && vendor/bin/pint`. Syntax: `php -l <file>`.
- Artisan (`route:list`, `php artisan test`, feature test) → chạy **trong Docker**.

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

## F. Bảo mật
- KHÔNG commit `.claude/settings.local.json` (đã gitignore — chứa path tuyệt đối + có thể chứa allowlist nhạy cảm).
- KHÔNG dán Personal Access Token vào chat/commit. Lỡ lộ → https://github.com/settings/tokens **revoke ngay** + tạo token mới. Repo team có `gitleaks` pre-commit chặn rò rỉ — giữ nguyên.

---

## G. Tham chiếu nhanh
| Muốn… | Làm |
|---|---|
| AI hiểu convention | Tự nạp (`CLAUDE.md`/`AGENTS.md`); AI lạ: dán `docs/ai/PROJECT-CONVENTIONS.md` |
| Review code | `/review` |
| Refactor giữ behavior | `/refactor` |
| Sinh docs FE | `/api-docs` |
| Sinh test | `/scaffold-test <path>` |
| Chạy test | `cd source && vendor/bin/phpunit tests/Unit/XTest.php` |
| Format | `cd source && vendor/bin/pint` |
| Cài máy mới | `./install.sh /path/to/hrm-api` + (Claude) dán `hooks-snippet.json` + (Codex) Trust all |
| Đồng bộ thay đổi | `./sync-from-project.sh` → commit → push → (máy kia) pull + install |
