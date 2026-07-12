# AGENTS.md — HRM API

> Quy ước cho **mọi AI / agentic IDE** (Antigravity, Cursor, Claude Code…). Đặt ở **project root** nên các công cụ này tự nạp mỗi phiên.
> **Nguồn chân lý đầy đủ:** [`docs/ai/PROJECT-CONVENTIONS.md`](docs/ai/PROJECT-CONVENTIONS.md) — LUÔN đọc & tuân thủ file đó.

## 3 rule cốt lõi
1. **Bám sát code thật — KHÔNG bịa.** Đọc/`grep` xác nhận class/method/field/route tồn tại trước khi dùng; không chắc thì tra cứu, không đoán.
2. **Reuse-first + DRY.** Tìm interface ở `Core/.../Shared/` + repo/util có sẵn trước khi tạo mới; lặp cùng logic ≥2 nơi → tách về `Shared/`/`Helper`/Trait, đừng copy. Khuôn mẫu: `source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/`.
3. **Repo code mới ưu tiên Eloquent ORM** (tránh `DB::table()`/raw cho ghi; legacy là ngoại lệ).

## Khuôn feature
1 feature = `<Feature>Command|Query` + `<Feature>Handler` (`declare(strict_types=1)`, `readonly` (trừ property Job cha abstract — xem §5), inject interface, gọi `validate()` đầu tiên, `BusinessException(<message user-facing theo i18n của module>, <httpCode>)`, return `array`) + `<Feature>ValidationInterface`. Code ở `source/src` (Core/Infrastructure/Presentation); Jobs/Console ở `source/app`.

## Response & Payload envelope (toàn cục)
- **Naming convention:** LUÔN dùng `camelCase` cho các trường dữ liệu API (input & output) và tên biến trong DTO.
- Thành công: `{ "data", "status":"success", "code":200, "message" }` (list thêm `links`, `meta`).
- Validation/`BusinessException` thường trả `{ "status":"error", "code", "message", "errors"? }`; auth/500 có legacy envelope khác — đọc `PROJECT-CONVENTIONS` §3.3, không giả định mọi lỗi giống nhau.

## Môi trường (QUAN TRỌNG)
- Chạy thật trong **Docker container `hrm-api`**; version pin gần nhất xem `PROJECT-CONVENTIONS` §12 và kiểm bằng `ai-php`. Host PHP chỉ để tham khảo, **không dùng làm chuẩn verify**.
- Không chạy trực tiếp `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` trên host khi kiểm tra code.
- Lệnh chuẩn cho AI sau khi sửa PHP: `make -f Makefile.ai ai-pint FILE=source/...` + `make -f Makefile.ai ai-lint FILE=source/...`; nếu có test tương ứng thì `make -f Makefile.ai ai-test TEST=tests/Unit/<X>Test.php`.
- Artisan chạy qua Docker: `make -f Makefile.ai ai-artisan CMD="route:list"`; kiểm PHP version: `make -f Makefile.ai ai-php CMD="-v"`.

## Tự kiểm tra sau khi sửa code (BẮT BUỘC — môi trường không có hook)
- Sau khi sửa/sinh `.php`: **TỰ chạy** `make -f Makefile.ai ai-lint FILE=...` (+ `ai-pint`, + `ai-test TEST=...` nếu có test) — coi như bước bắt buộc, không bỏ.
- **TUYỆT ĐỐI không** chạy `php`/`composer`/`php artisan`/`vendor/bin/phpunit`/`vendor/bin/pint` trên host (đây là vai trò của PreToolUse guard mà IDE không bắn → phải tự kỷ luật).
- Trước khi tạo class/method mới: **tự tìm reuse** (xem mục find-reuse) trong `Core/Components/<Module>/Shared/`, `Infrastructure/<Module>/Repositories/`, `Infrastructure/Shared/Helper.php`, `*Trait`.

## Prompt tái dùng (Backed by `docs/ai/prompts/*.md`)
- Review diff: `docs/ai/prompts/review.md` · Đối chiếu code với Plan (`/review-vs-plan`): `docs/ai/prompts/review-vs-plan.md` · Review/Refactor: `docs/ai/prompts/refactor.md`
- Sinh docs FE: `docs/ai/prompts/generate-api-docs.md` · Sinh test: `docs/ai/prompts/generate-test.md`
- Sinh feature (`/scaffold-feature`): `docs/ai/prompts/generate-feature.md` · Tự sinh git commit (`/commit-message`): `docs/ai/prompts/commit-message.md` · Tìm reuse (`/find-reuse`): `docs/ai/prompts/find-reuse.md`.
- Bẻ việc / bóc task / estimate (`/task-breakdown`): `docs/ai/prompts/task-breakdown.md` — chia theo Technical Boundary, ma trận Size×Effort→Point (trần 2 Point/task), reuse-first, không cộng trùng.
- **Mới:** Triển khai yêu cầu (`/implement`): `docs/ai/prompts/implement-requirement.md` · Adversarial verify (`/verify`): `docs/ai/prompts/adversarial-verify.md` · Review diff + commit (`/diff-review`): `docs/ai/prompts/diff-review.md` · Sinh docs code BE (`/code-docs`): `docs/ai/prompts/generate-code-docs.md`.
- Docs FE viết vào `api-docs/<Module>/<Endpoint>.md` (contract-only) — KHÁC `docs/` (logic nội bộ BE).
