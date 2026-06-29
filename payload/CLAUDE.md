# CLAUDE.md — HRM API

**Nguồn chân lý (đọc & tuân thủ trước khi code/review/viết docs):** [`docs/ai/PROJECT-CONVENTIONS.md`](docs/ai/PROJECT-CONVENTIONS.md).
File này chỉ tóm tắt; chi tiết + lý do nằm ở đó.

## 3 rule cốt lõi
1. **Bám sát code thật — KHÔNG bịa.** Đọc/`grep` xác nhận class/method/field/route tồn tại trước khi dùng; không chắc thì tra cứu, không đoán. (PROJECT-CONVENTIONS §0)
2. **Reuse-first + DRY.** Tìm interface ở `Core/.../Shared/` và repo/util hiện có để tái dùng trước khi tạo mới; lặp cùng logic ≥2 nơi → tách về `Shared/`/`Helper`/Trait, đừng copy. Khuôn mẫu: `source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/`. (§1)
3. **Repo code mới ưu tiên Eloquent ORM** (tránh `DB::table()`/raw cho ghi; legacy query-builder là ngoại lệ). (§4)

## Khuôn feature
1 feature = `<Feature>Command|Query` + `<Feature>Handler` (`declare(strict_types=1)`, `readonly`, inject interface, `validate()` đầu tiên, `BusinessException(<VN>, <httpCode>)`, return `array`) + `<Feature>ValidationInterface`. Code ở `source/src` (Core/Infrastructure/Presentation); Jobs/Console ở `source/app`.

## Môi trường (QUAN TRỌNG)
- Chạy thật trong **Docker container `hrm-api` (PHP 8.2.31)**. Host PHP có thể mới hơn, nhưng **không dùng làm chuẩn verify**.
- Không chạy trực tiếp `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` trên host khi kiểm tra code.
- Lệnh chuẩn cho AI: `make ai-lint FILE=source/...`, `make ai-pint FILE=source/...`, `make ai-test TEST=tests/Unit/XTest.php`, `make ai-artisan CMD="route:list"`, `make ai-php CMD="-v"`.

## Slash commands
- `/review` → review diff theo checklist dự án (`docs/ai/prompts/review.md`).
- `/api-docs` → sinh docs FE contract-only vào `api-docs/<Module>/<Endpoint>.md` (`docs/ai/prompts/generate-api-docs.md`).
- `/scaffold-test` → sinh unit test Mockery vào `source/tests/Unit/` (`docs/ai/prompts/generate-test.md`).
- `/refactor` → review/refactor code giữ behavior, có mức độ 🔴🟡🟢 (`docs/ai/prompts/refactor.md`).
