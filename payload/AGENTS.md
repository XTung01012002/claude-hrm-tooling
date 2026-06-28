# AGENTS.md — HRM API

> Quy ước cho **mọi AI / agentic IDE** (Antigravity, Cursor, Claude Code…). Đặt ở **project root** nên các công cụ này tự nạp mỗi phiên.
> **Nguồn chân lý đầy đủ:** [`docs/ai/PROJECT-CONVENTIONS.md`](docs/ai/PROJECT-CONVENTIONS.md) — LUÔN đọc & tuân thủ file đó.

## 3 rule cốt lõi
1. **Bám sát code thật — KHÔNG bịa.** Đọc/`grep` xác nhận class/method/field/route tồn tại trước khi dùng; không chắc thì tra cứu, không đoán.
2. **Reuse-first + DRY.** Tìm interface ở `Core/.../Shared/` + repo/util có sẵn trước khi tạo mới; lặp cùng logic ≥2 nơi → tách về `Shared/`/`Helper`/Trait, đừng copy. Khuôn mẫu: `source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/`.
3. **Repo code mới ưu tiên Eloquent ORM** (tránh `DB::table()`/raw cho ghi; legacy là ngoại lệ).

## Khuôn feature
1 feature = `<Feature>Command|Query` + `<Feature>Handler` (`declare(strict_types=1)`, `readonly`, inject interface, gọi `validate()` đầu tiên, `BusinessException(<VN>, <httpCode>)`, return `array`) + `<Feature>ValidationInterface`. Code ở `source/src` (Core/Infrastructure/Presentation); Jobs/Console ở `source/app`.

## Response envelope (toàn cục — `source/bootstrap/app.php` + `ApiBaseController`)
- Thành công: `{ "data", "status":"success", "code":200, "message" }` (list thêm `links`, `meta`).
- Lỗi: `{ "status":"error", "code", "message", "errors"? }`; validation fail → **422**.

## Môi trường (QUAN TRỌNG)
- Chạy thật trong **Docker (PHP 8.2.31)**. Local PHP mới hơn → `composer install`/`php artisan` local **FAIL**.
- Test local: `cd source && vendor/bin/phpunit tests/Unit/XTest.php`. Format: `cd source && vendor/bin/pint`. Syntax: `php -l <file>`.
- Artisan (`route:list`, `php artisan test`, feature test) → chạy **trong Docker**.
- **Tự format/kiểm sau khi sửa** (Antigravity/Codex không có hook tự động như Claude Code): mỗi khi tạo/sửa 1 file `.php`, hãy **tự chạy** `cd source && vendor/bin/pint <file>` (format) + `php -l <file>` (syntax); nếu file có test tương ứng thì chạy `cd source && vendor/bin/phpunit tests/Unit/<X>Test.php` trước khi báo hoàn tất.

## Prompt tái dùng
- Review: `docs/ai/prompts/review.md` · Review/Refactor: `docs/ai/prompts/refactor.md` · Sinh docs FE: `docs/ai/prompts/generate-api-docs.md` · Sinh test: `docs/ai/prompts/generate-test.md`
- Docs FE viết vào `api-docs/<Module>/<Endpoint>.md` (contract-only) — KHÁC `docs/` (logic nội bộ BE).
