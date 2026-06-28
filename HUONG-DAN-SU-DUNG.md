# Hướng dẫn sử dụng — Bộ AI tooling cho HRM API

Tài liệu này hướng dẫn dùng bộ tooling giúp **vibe-coding với AI** đúng chuẩn, tự kiểm tra, và tự sinh docs FE — cho dự án **HRM API**.

Triết lý: **(1)** AI code đúng ngay từ đầu (nhờ convention nạp sẵn) → đỡ phải review sửa nhiều vòng; **(2)** mọi quy ước/prompt là markdown **trung lập** (dùng cho Claude, ChatGPT, Cursor, Gemini…); **(3)** nguyên tắc số 1: **bám sát code thật, cấm AI bịa**.

---

## 1. Hệ thống gồm gì

| Thành phần | Đường dẫn (trong project) | Vai trò |
|---|---|---|
| Nguồn chân lý | `docs/ai/PROJECT-CONVENTIONS.md` | Toàn bộ quy ước + bẫy (dùng cho **mọi AI**) |
| Prompt tái dùng | `docs/ai/prompts/{review,generate-api-docs,generate-test}.md` | Logic cho review / sinh docs / sinh test |
| Lối tắt Claude | `CLAUDE.md` | Tóm tắt, trỏ về `docs/ai/` (Claude tự nạp mỗi phiên) |
| Slash commands | `.claude/commands/{review,api-docs,scaffold-test}.md` | `/review`, `/api-docs`, `/scaffold-test` |
| Hooks | `.claude/hooks/{php-lint.sh,run-related-tests.sh}` | Tự lint/format + chạy test liên quan |
| Đăng ký hook | `.claude/settings.local.json` (khối `hooks`) | Cá nhân, **không** commit |
| Docs FE | `api-docs/<Module>/<Endpoint>.md` | Hợp đồng gọi API cho FE (contract-only) |

> `docs/` (đã có sẵn) là tài liệu **logic nội bộ** cho BE — KHÁC `api-docs/` (cho FE). Đừng nhầm.

---

## 2. Cài đặt trên một máy mới (vd máy công ty)

```bash
# 1) Kéo bộ tooling về
git clone https://github.com/XTung01012002/claude-hrm-tooling.git
cd claude-hrm-tooling

# 2) Cài vào project HRM
./install.sh /duong-dan/toi/hrm-api
```

Sau đó:
1. **Đăng ký hook**: mở `hooks-snippet.json` trong repo này, copy khối `"hooks"` vào `<project>/.claude/settings.local.json` (nếu file chưa có thì tạo mới với nội dung đó; nếu có rồi thì chèn thêm key `hooks`, đừng ghi đè).
2. **Khởi động lại Claude Code** để hook có hiệu lực.
3. (Tùy chọn) **Bước 0 — bật `php artisan`**: xem mục [6. Môi trường](#6-môi-trường-local--docker).

---

## 3. Quy trình hằng ngày (ánh xạ 4 khâu)

```
Nhận yêu cầu  ─►  Vibe coding  ─►  Review / đối chiếu  ─►  Viết docs FE
   (Plan mode)     (hook tự         (/review + Stop hook      (/api-docs)
                    lint/format)      tự chạy test)
```

1. **Nhận yêu cầu** → bật **Plan mode** (Shift+Tab trong Claude Code). AI đã nạp `CLAUDE.md`/`PROJECT-CONVENTIONS.md` nên hiểu convention + reuse-first + cấm bịa ngay.
2. **Vibe coding** → AI bám khuôn `SaveZaloAccountStaff`, tái dùng interface/repo có sẵn. Mỗi lần AI sửa file `.php`, hook **PostToolUse** tự chạy `php -l` + Pint format.
3. **Review** → kết thúc lượt, hook **Stop** tự chạy test liên quan (map từ `git diff`). Gõ **`/review`** để soát theo checklist dự án (reuse, layering, ORM, bẫy, convention) — mọi finding được verify bằng code thật.
4. **Docs FE** → gõ **`/api-docs`** để sinh/cập nhật `api-docs/<Module>/<Endpoint>.md`, chỉ cần soát lại.

---

## 4. Slash commands (trong Claude Code)

### `/review`
Review thay đổi hiện tại (`git diff`) theo checklist riêng của dự án. Output nhóm **Cao / Trung bình / Thấp** kèm `file:line` + cách sửa; mỗi finding đã verify bằng grep/đọc code.
```
/review                      # review toàn bộ git diff
/review src/.../XHandler.php  # giới hạn vào file/đường dẫn
```

### `/api-docs`
Sinh tài liệu API contract-only cho FE từ **code thật** (Controller → Command/Query → Validation impl → Handler → Resource/Mapper). Ghi 1 file/endpoint vào `api-docs/<Module>/<Endpoint>.md`, cập nhật `api-docs/README.md`.
```
/api-docs                         # các controller mới/đổi trong git diff
/api-docs ListZaloContactsController   # 1 endpoint cụ thể
```

### `/scaffold-test`
Sinh unit test PHPUnit + Mockery (AAA) cho 1 class, phủ happy-path + các nhánh `BusinessException`.
```
/scaffold-test source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/SaveZaloAccountStaffHandler.php
```

> Mỗi command chỉ là file mỏng trỏ về `docs/ai/prompts/*.md`. Sửa hành vi command = sửa prompt tương ứng.

---

## 5. Hooks — cái gì chạy khi nào

| Hook | Khi nào | Làm gì |
|---|---|---|
| `php-lint.sh` | Sau mỗi Edit/Write file `.php` | `php -l` (chặn nếu lỗi cú pháp) + `vendor/bin/pint` (auto-format file vừa sửa) |
| `run-related-tests.sh` | Khi AI kết thúc lượt (Stop) | Map file đã đổi → `*Test.php` tương ứng, chạy `vendor/bin/phpunit`. **Không có test tương ứng → bỏ qua êm** (không chạy full suite) |

- Hook đọc đường dẫn từ stdin (có fallback nhiều key), chuẩn hóa absolute path → an toàn.
- **Tắt tạm**: xóa/đổi tên khối `hooks` trong `.claude/settings.local.json` rồi khởi động lại phiên.
- Format **không** check ở Stop (tránh false-fail do file dirty có sẵn) — Pint đã chạy ở từng lần Edit/Write.

---

## 6. Môi trường (local ≠ Docker) — RẤT QUAN TRỌNG

- Dự án chạy thật trong **Docker (PHP 8.2.31)**. Máy local thường là PHP mới hơn (vd 8.5) → **`composer install` local sẽ fail** (deps trong lock yêu cầu 8.2–8.4). Cài deps phải trong container: `make shell` → `composer install` → `make copy-vendor`.
- **Chạy unit test (local OK)**: `cd source && vendor/bin/phpunit tests/Unit/XTest.php` (unit test thuần Mockery/Reflection không boot app nên chạy được trên PHP mới).
- **`php artisan ...` (route:list, php artisan test, feature test)** → chạy **trong Docker**. Nếu local boot fail do thiếu `vendor/laravel/horizon`: trong Docker chạy `composer install`; hoặc tạm thời (chỉ local, **không commit**) comment dòng `App\Providers\HorizonServiceProvider::class` trong `bootstrap/providers.php`.
- **Format**: `cd source && vendor/bin/pint`. **Syntax**: `php -l <file>`. (đều chạy local OK)

---

## 7. Dùng với AI khác (không phải Claude)

Mọi logic nằm ở `docs/ai/` dạng markdown thuần. Mỗi công cụ có 1 file "tự nạp mỗi phiên" riêng — set 1 lần, khỏi dán tay.

### Tự nạp mỗi phiên (khuyến nghị) — đã có sẵn `AGENTS.md` ở project root
`AGENTS.md` (root) là **chuẩn cross-tool**: **Antigravity, Cursor, Claude Code** đều đọc tự động. Nó tóm tắt 3 rule + khuôn feature + môi trường và trỏ về `docs/ai/PROJECT-CONVENTIONS.md`.

| Công cụ | File tự nạp | Ghi chú |
|---|---|---|
| **Antigravity** | `AGENTS.md` (project root) | Tự nạp. *(Tuỳ chọn: thêm rule "Always On" trong panel Rules của Antigravity, hoặc đặt file trong thư mục rules của workspace — kiểm tra đúng tên `.agent/rules/` hay `.agents/rules/` trong Settings → Rules của bản bạn đang dùng, 2 tài liệu ghi khác nhau.)* |
| **Cursor** | `AGENTS.md` (root) hoặc `.cursor/rules/*.mdc` | `AGENTS.md` đủ dùng; muốn chi tiết hơn thì tạo rule trong `.cursor/rules/`. |
| **Claude Code** | `CLAUDE.md` (đã có) | Đã tự nạp. |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Tạo file trỏ về `docs/ai/PROJECT-CONVENTIONS.md` nếu cần. |
| **ChatGPT** | Projects / Custom Instructions | Dán nội dung `docs/ai/PROJECT-CONVENTIONS.md` 1 lần. |

> Antigravity chạy nền Gemini: global rules ở `~/.gemini/` (vd `~/.gemini/AGENTS.md` cho mọi project). Ở đây ta dùng **project-level** nên đặt `AGENTS.md` ngay trong repo.

### Khi cần thao tác cụ thể (mọi AI)
- Review → dán `docs/ai/prompts/review.md` + `git diff`.
- Docs FE → dán `docs/ai/prompts/generate-api-docs.md` + code endpoint.
- Test → dán `docs/ai/prompts/generate-test.md` + code class.

---

## 8. Quy ước cốt lõi (tóm tắt — chi tiết ở `docs/ai/PROJECT-CONVENTIONS.md`)

- **§0 Cấm bịa**: đọc/grep xác nhận class/method/field/route tồn tại trước khi dùng.
- **§1 Reuse-first**: tìm interface ở `Core/.../Shared/` + repo/util có sẵn trước khi tạo mới. Khuôn vàng: `SaveZaloAccountStaff/`.
- **§2 Layering**: Core ưu tiên chỉ phụ thuộc interface ở `Shared/`, hạn chế import class Infrastructure cụ thể.
- **§3 Feature**: `<Feature>Command|Query` + `<Feature>Handler` (`strict_types`, `readonly`, `validate()` đầu tiên, `BusinessException(<VN>, <httpCode>)`, return `array`) + `<Feature>ValidationInterface`.
- **§4 Repo**: code mới ưu tiên **Eloquent ORM** (tránh `DB::table()` cho ghi; legacy là ngoại lệ).
- **§5 Bẫy**: `PlatformTime::parse()` cho timestamp Zalo; Carbon 3 `diffIn*` có dấu; queue `retry_after` 700 > worker `timeout`.

---

## 9. Đồng bộ nhiều máy

```bash
# Máy gốc — sau khi tooling thay đổi:
cd /duong-dan/toi/claude-hrm-tooling
./sync-from-project.sh /duong-dan/toi/hrm-api     # copy file mới nhất từ project về payload/
git add -A && git commit -m "update tooling" && git push

# Máy công ty:
git pull && ./install.sh /duong-dan/toi/hrm-api
```

---

## 10. Bảo mật

- **Không** commit `.claude/settings.local.json` (đã được gitignore) — nó chứa path tuyệt đối theo máy.
- **Không bao giờ** dán Personal Access Token vào chat/commit. Nếu lỡ lộ → vào https://github.com/settings/tokens **revoke ngay** và tạo token mới.
- Repo team có `gitleaks` pre-commit để chặn rò rỉ secret — giữ nguyên.

---

## 11. Tham chiếu nhanh

| Muốn… | Làm |
|---|---|
| AI hiểu convention | Đã tự nạp qua `CLAUDE.md`; AI khác: dán `docs/ai/PROJECT-CONVENTIONS.md` |
| Review code | `/review` |
| Sinh docs FE | `/api-docs` |
| Sinh test | `/scaffold-test <path>` |
| Chạy test local | `cd source && vendor/bin/phpunit tests/Unit/XTest.php` |
| Format | `cd source && vendor/bin/pint` |
| Cài lên máy mới | `./install.sh /path/to/hrm-api` + dán `hooks-snippet.json` |
| Đồng bộ thay đổi | `./sync-from-project.sh` → commit → push |
