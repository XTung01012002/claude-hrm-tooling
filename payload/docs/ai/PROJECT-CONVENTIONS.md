# PROJECT CONVENTIONS — HRM API (Gopany)

> **Tài liệu trung lập (AI-agnostic).** Đưa file này cho bất kỳ AI nào (Claude / ChatGPT / Cursor / Copilot / Gemini) trước khi nhờ code/review/viết docs. Nội dung được rút ra & **verify từ code thật** trong `source/`, không phải quy ước lý thuyết.
>
> Lớp tiện ích Claude (`CLAUDE.md`, `.claude/commands/*`, `.claude/hooks/*`) chỉ **trỏ về** file này — đây mới là nguồn chân lý.

---

## §0. Nguyên tắc nền tảng — BÁM SÁT CODE THẬT, KHÔNG BỊA

**Đây là quy tắc số 1, đứng trên mọi quy tắc khác.**

- Trước khi viết/sửa/ghi docs: **đọc file liên quan** và `grep` để xác nhận tên class / method / field / route / enum **thực sự tồn tại**.
- Chỉ dùng interface / method / field **có thật** trong codebase. Không chắc → tra cứu, **không đoán**.
- **Không bịa**: không bịa field response, không bịa rule validate, không bịa endpoint, không bịa giá trị enum.
- Khi review hay viết docs: mỗi khẳng định phải truy được về `file:line` thật. Nếu không kiểm chứng được → nói rõ "chưa kiểm chứng", đừng khẳng định.

---

## §1. Reuse-first — tái sử dụng thay vì tạo mới

- **Trước khi tạo mới** class / interface / method: BẮT BUỘC tìm trong:
  - `source/src/Core/Components/<Module>/Shared/*Interface.php` (các contract dùng chung)
  - các Repository hiện có (`source/src/Infrastructure/<Module>/Repositories/*`)
  - util dùng chung trong `Shared/` (vd `PlatformTime`, `TagNameNormalizer`)
- Ưu tiên gọi lại method repo/interface đã có hơn là viết logic truy vấn mới.
- **Khuôn mẫu vàng**: `source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/SaveZaloAccountStaffHandler.php` — Handler chỉ inject interface, tái dùng `findZaloAccount`, `syncAccountStaff`, `findActiveCompanyUserUids`, `forgetThreadUserAccess`.

---

## §2. Kiến trúc & phân tầng

```
source/src/
  Core/Components/<Module>/<Feature>/   # nghiệp vụ: Command/Query + Handler + ValidationInterface
  Core/Components/<Module>/Shared/      # interface dùng chung (Repository/Api/Cache/Dispatcher...), enum, util
  Infrastructure/<Module>/             # impl: Repositories, Models, Mappers, Validations, Providers
  Presentation/API/Controllers/        # Controller mỏng (Spatie Route Attributes)
source/app/                            # Jobs, Console commands, Providers, Filament (KHÔNG nằm ở src)
```

Luồng 1 request: **Controller → Command/Query → ValidationInterface → Handler → Repository (qua interface)**.

- **Chuẩn mới ưu tiên:** Core chỉ phụ thuộc **interface** ở `Shared/`, **hạn chế** import class Infrastructure cụ thể.
- *Ngoại lệ legacy đã tồn tại* (KHÔNG coi là khuôn để nhân rộng): `CreateTagHandler` import `Infrastructure\...\Mappers\ChatTagMapper`; `OmnichannelPermissionChecker` dùng trait `Infrastructure\User\Traits\ResolvesUsersByAccountPermissionSubject`. Nếu viết feature mới, đừng bắt chước các ngoại lệ này.

---

## §3. Convention code (1 feature = 3 file)

Theo khuôn `SaveZaloAccountStaff/`:

- `<Feature>Command.php` (ghi) / `<Feature>Query.php` (đọc): DTO `readonly`, có `public static function fromRequest(Request $request): self` (lấy `companyId` từ `auth('api')->user()`, ép kiểu input).
- `<Feature>Handler.php`:
  - `declare(strict_types=1);`
  - `readonly class`, constructor inject **interface** (validation, repo, api, cache...).
  - Gọi `$this->validation->validate($command)` **đầu tiên**.
  - Ném lỗi nghiệp vụ bằng `BusinessException(<message tiếng Việt>, <httpCode>)` (`Gopany\Core\Components\Shared\BusinessException`).
  - Dùng enum qua `->value` (vd `FriendshipStatusEnum::REJECTED->value`).
  - `handle(...)` trả về `array`.
  - Tách helper `private` có docblock tiếng Việt.
- `<Feature>ValidationInterface.php`: contract `validate(<Command> $command): void`. Impl ở `Infrastructure/<Module>/Validations/<Feature>Validation.php`, bind trong ServiceProvider của module.

**Response envelope** (toàn cục, ở `source/bootstrap/app.php` + `ApiBaseController`):
- Detail/action thành công: `jsonResponse($data, $message)` → `{ "data": {...}, "status": "success", "code": 200, "message": "..." }`
- List thành công: `jsonResponseMeta($data, $message)` → `{ "data": [...], "links": {...}, "meta": {...}, "status": "success", "code": 200, "message": "..." }`
- Lỗi (render ở `bootstrap/app.php`): `{ "status": "error", "code": <http|string>, "message": "...", "errors"?: {...} }`
  - `ValidationException` → 422, `message` = lỗi đầu tiên, `errors` = `{ field: <message đầu> }`
  - `BusinessException` → `code` = httpCode đặt trong Handler, kèm `errors` nếu có
  - `ModelNotFound`/`NotFoundHttp` → 404, `Unauthorized` → 401, `AccessDenied` → 403, còn lại → 500

---

## §4. Repository — code mới ưu tiên Eloquent ORM

- Code **mới** hoặc đoạn repo **bạn sửa**: dùng Eloquent Model (`Model::create`, `->update`, `->where`, relationships, `::withTrashed()`...) → cast (`$casts`) tự áp dụng.
- **Tránh** `DB::table()` / `DB::raw()` cho ghi: query-builder bỏ qua cast → MySQL strict ném **1292** khi nhét chuỗi ISO vào cột datetime. Nếu *buộc* dùng query-builder cho cột datetime, truyền `Carbon`, không phải chuỗi ISO.
- **Ngoại lệ legacy**: nhiều repo hiện vẫn dùng query-builder, vd `OmnichannelChatRepository::syncAccountStaff()` dùng `DB::table('zalo_account_users')->delete()/insert()/update()`. Đây là legacy — nếu chạm vào thì cân nhắc migrate sang Eloquent hoặc ghi chú lý do; **đừng copy** làm khuôn cho code mới.
- List/filter dùng **Spatie QueryBuilder** (dựa trên Eloquent) là chấp nhận được.

---

## §5. Các "bẫy" đã biết (đã gặp & verify)

- **Timestamp Zalo**: webhook/API trả epoch dạng số (ms hoặc giây) → dùng `Gopany\Core\Components\OmnichannelChat\Shared\PlatformTime::parse()`, KHÔNG `Carbon::parse()` thô (parse sai âm thầm).
- **Carbon 3 signed diff**: `diffIn*()` trả **có dấu** (âm khi đối số ở quá khứ) → dễ hỏng logic so ngưỡng thời gian. Bọc `abs()` nếu cần độ lớn.
- **Cột datetime + query-builder**: truyền `Carbon`, không phải chuỗi ISO (xem §4).
- **Queue/Horizon** (đã verify):
  - `config/queue.php`: chỉ 1 connection `redis`, `retry_after` = 700 (env `REDIS_QUEUE_RETRY_AFTER`).
  - `config/horizon.php`: các queue `chat` / `chat-heavy` / `domain` là **supervisor** trên cùng connection `redis`, đặt `timeout` riêng (chat **60** / chat-heavy **610** / domain **600**) — KHÔNG phải `retry_after` riêng.
  - Quy tắc: `timeout` worker phải **< `retry_after`** của connection, tránh job chạy trùng.
- **PHP 8.2 + Job cha abstract**: tránh `readonly` ở property của abstract Job cha — fail unserialize với `SerializesModels` (reflection). (Container chạy PHP 8.2.31.)

---

## §6. Test (PHPUnit + Mockery)

- Đặt ở `source/tests/Unit/` (thuần, không boot app) hoặc `source/tests/Feature/`.
- Unit test thuần: extend `PHPUnit\Framework\TestCase` hoặc `Tests\TestCase`; mock dependency bằng `Mockery::mock(SomeInterface::class)`.
- `tearDown()` gọi `Mockery::close();` (và `Carbon::setTestNow();` nếu có mock thời gian) rồi `parent::tearDown();`.
- Tên test: `test_<scenario>_<expected_outcome>()`. Cấu trúc **Arrange–Act–Assert**. Ưu tiên `self::assertSame()` hơn `assertTrue`.
- Mock kỳ vọng: `->shouldReceive('m')->once()->with(...)->andReturn(...)`; `->shouldNotReceive(...)` để verify không gọi.
- File mẫu: `tests/Unit/ChatZaloApiTest.php`, `tests/Unit/GetFriendStatusHandlerTest.php`, `tests/Unit/FriendshipEventHandlerTest.php`.

---

## §7. Lệnh & môi trường (QUAN TRỌNG — local ≠ Docker)

- **Môi trường thật là Docker** (PHP **8.2.31**). Máy local hiện chạy **PHP 8.5** → **không tương thích** deps trong `composer.lock` (lcobucci/clock, openspout, phpspreadsheet yêu cầu 8.2–8.4) → **`composer install` chạy local sẽ fail**. Cài deps phải làm trong container: `make shell` → `composer install` → `make copy-vendor`.
- **Chạy unit test (local OK)**: `cd source && vendor/bin/phpunit tests/Unit/XTest.php` — unit test thuần (Mockery/Reflection) chạy được trên PHP 8.5 vì không boot app.
- **`php artisan ...` hiện boot fail trên local** (thiếu `vendor/laravel/horizon`, và PHP 8.5). Dùng artisan (`route:list`, `make:*`, `php artisan test`, feature test) **trong Docker**. Nếu cần artisan local tạm thời (không commit): comment `App\Providers\HorizonServiceProvider::class` ở `bootstrap/providers.php`.
- **Format**: `cd source && vendor/bin/pint` (hoặc `vendor/bin/pint --dirty` chỉ file chưa commit) — chạy local OK.
- **Syntax check**: `php -l <file>` — chạy local OK.
