# CLAUDE.md — HRM API

**Nguồn chân lý (đọc & tuân thủ trước khi code/review/viết docs):** [`docs/ai/PROJECT-CONVENTIONS.md`](docs/ai/PROJECT-CONVENTIONS.md).
File này chỉ tóm tắt; chi tiết + lý do nằm ở đó.

## 4 rule cốt lõi
0. **Đồng nhất domain:** Trước khi đặt tên biến, class hoặc mô tả nghiệp vụ, đọc `docs/ai/CONTEXT.md`.
1. **Bám sát code thật — KHÔNG bịa.** Đọc/`grep` xác nhận class/method/field/route tồn tại trước khi dùng; không chắc thì tra cứu, không đoán. (PROJECT-CONVENTIONS §0)
2. **Reuse-first + DRY.** Tìm interface ở `Core/.../Shared/` và repo/util hiện có để tái dùng trước khi tạo mới; lặp cùng logic ≥2 nơi → tách về `Shared/`/`Helper`/Trait, đừng copy. Khuôn mẫu: `source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/`. (§1)
3. **Repo code mới ưu tiên Eloquent ORM** (tránh `DB::table()`/raw cho ghi; legacy query-builder là ngoại lệ). (§4)

## Khuôn feature
1 feature = `<Feature>Command|Query` + `<Feature>Handler` (`declare(strict_types=1)`, `readonly` (trừ property Job cha abstract — xem §5), inject interface, gọi `validate()` đầu tiên, `BusinessException(<message user-facing theo i18n của module>, <httpCode>)`, return `array`) + `<Feature>ValidationInterface`. Code ở `source/src` (Core/Infrastructure/Presentation); Jobs/Console ở `source/app`.

## Response & Payload envelope (toàn cục)
- **Naming convention:** LUÔN dùng `camelCase` cho các trường dữ liệu API (input & output) và tên biến trong DTO.
- Thành công: `{ "data", "status":"success", "code":200, "message" }` (list thêm `links`, `meta`).
- Validation/`BusinessException` thường trả `{ "status":"error", "code", "message", "errors"? }`; auth/500 có legacy envelope khác — đọc `PROJECT-CONVENTIONS` §3.3, không giả định mọi lỗi giống nhau.

## Môi trường (QUAN TRỌNG)
- Chạy thật trong **Docker container `hrm-api`**; version pin gần nhất xem `PROJECT-CONVENTIONS` §12 và kiểm bằng `ai-php-version`. Host PHP có thể mới hơn, nhưng **không dùng làm chuẩn verify**.
- Không chạy trực tiếp `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` trên host khi kiểm tra code.
- Lệnh chuẩn cho AI: `AI_FILE=source/... make -f Makefile.ai ai-lint`, `AI_FILE=source/... make -f Makefile.ai ai-pint`, `AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test`, `make -f Makefile.ai ai-route-list`, `AI_ROUTE_PATH=api/v1/... make -f Makefile.ai ai-route-list`, `make -f Makefile.ai ai-php-version`. Lệnh ghi dữ liệu (migrate, seed, cache:clear...) phải chạy tay.

## Slash commands & Skills (Backed by `docs/ai/prompts/*.md`)
- `/review` → review diff theo checklist, verdict `PASS` / `PASS_WITH_CONCERNS` / `REQUEST_CHANGES` / `BLOCKED_INSUFFICIENT_CONTEXT` (`docs/ai/prompts/review.md`).
- `/review-vs-plan` → reviewer độc lập đối chiếu implementation với Plan cuối, thay đổi ngoài Plan và chất lượng code (`docs/ai/prompts/review-vs-plan.md`).
- `/implement` → triển khai yêu cầu theo quy trình 10 bước — phân tích trước, code sau (`docs/ai/prompts/implement-requirement.md`).
- `/scaffold-test` → sinh unit test Mockery, test matrix 14 nhóm (`docs/ai/prompts/generate-test.md`).
- `/scaffold-feature` → sinh template 3 file feature theo chuẩn (`docs/ai/prompts/generate-feature.md`).
- `/api-docs` → sinh docs FE contract-only + lưu ý cho FE (`docs/ai/prompts/generate-api-docs.md`).
- `/code-docs` → sinh tài liệu code nội bộ cho BE (`docs/ai/prompts/generate-code-docs.md`).
- `/diff-review` → review diff → verdict → branch + commit + PR (`docs/ai/prompts/diff-review.md`).
- `/commit-message` → sinh nội dung git commit (nhanh, không review) (`docs/ai/prompts/commit-message.md`).
- `/verify` → adversarial verification — kiểm định cuối, chỉ kiểm không sửa (`docs/ai/prompts/adversarial-verify.md`).
- `/refactor` → review/refactor code giữ behavior, có mức độ 🔴🟡🟢 (`docs/ai/prompts/refactor.md`).
- `/find-reuse` → tìm logic/interface có thể tái sử dụng trước khi tạo mới (`docs/ai/prompts/find-reuse.md`).
- `/task-breakdown` → Task breakdown: `.agents/skills/task-breakdown/SKILL.md`
- `/debug` → Chẩn đoán bug qua 6 bước (Dựng test đỏ, Thu nhỏ, Giả thuyết, Instrument, Fix, Dọn dẹp) (`.claude/commands/debug.md`).
- `/grill` → Phỏng vấn từng câu một kèm đề xuất trước khi implement (`.claude/commands/grill.md`).
