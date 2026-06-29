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
- **DRY — lặp ≥2 nơi thì tách dùng chung:** nếu code mới/đang sửa lặp cùng 1 logic ở **≥2 file/chỗ** (hoặc copy 1 helper), tách về **1 chỗ** rồi gọi lại, KHÔNG copy. Nơi đặt theo pattern repo:
  - Hàm thuần/stateless → `Core/<Module>/Shared/<Name>` (như `PlatformTime`, `TagNameNormalizer`) hoặc static method trên enum liên quan.
  - Tiện ích cross-cutting → `Infrastructure/Shared/Helper.php`.
  - Behavior chia sẻ giữa nhiều class → Trait ở `Infrastructure/.../Traits/` (vd `ResolvesUsersByAccountPermissionSubject`).
  - Ví dụ đang lặp cần gom: `preserveRejectedStatus()` (đang copy ở `GetFriendStatusHandler` + `SearchZaloContactHandler`).
  - **Đừng over-engineer**: chỉ tách khi thật sự dùng ≥2 nơi (hoặc chắc chắn sẽ tái dùng); 1 chỗ dùng → để `private` method, không tạo abstraction thừa.

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
- **Job/Queue**: đặt `tries` + `backoff()`; re-query DB trong job nếu dữ liệu có thể stale; `WithoutOverlapping` khi cùng key không được chạy song song; không nuốt exception nếu cần retry (log rồi `throw` lại).

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

- **Môi trường thật là Docker container `hrm-api`** (PHP **8.2.31**). Host PHP có thể mới hơn (vd PHP 8.5) nên **không dùng làm chuẩn verify**.
- **Không chạy trực tiếp trên host**: `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` khi kiểm tra code. Host PHP mới hơn có thể lint pass syntax không tương thích PHP 8.2.
- **Lệnh chuẩn cho AI/agent**:
  - Syntax PHP 8.2: `make ai-lint FILE=source/path/to/File.php`
  - Format 1 file: `make ai-pint FILE=source/path/to/File.php`
  - Format + lint 1 file: `make ai-check FILE=source/path/to/File.php`
  - Unit test: `make ai-test TEST=tests/Unit/XTest.php`
  - Artisan: `make ai-artisan CMD="route:list"`
  - Kiểm PHP container: `make ai-php CMD="-v"`
- Composer/deps vẫn chạy trong container (`make shell` → `composer install` → `make copy-vendor`) hoặc dùng các target composer sẵn có của `Makefile`.

---

## §8. Multi-tenancy & Security

- Query dữ liệu thuộc tenant **LUÔN** filter `company_id` (+ `omnichannel_account_id` / `store_id` khi dữ liệu thuộc account/store). KHÔNG query chỉ bằng `id` cho dữ liệu tenant → rò rỉ chéo công ty.
  - Verified: mọi method `ZaloContactRepository` pair `company_id` + `omnichannel_account_id` (`findContact`, `paginateContacts`).
  - Sai: `Model::find($id)`. Đúng: `Model::where('company_id', $companyId)->where('id', $id)->first()`.
- KHÔNG log token / secret / signature / payload nhạy cảm.
- Trước khi gọi API ngoài (Zalo): check account tồn tại + đúng `company_id` + `connection_status === CONNECTED`, và validate payload.

---

## §9. Transaction, race condition & webhook

- `DB::transaction()` khi 1 use case ghi **nhiều bảng** cần atomic (vd sync staff: delete + insert + update). KHÔNG bọc transaction cho query đọc đơn giản.
- `lockForUpdate()` cho read-modify-write dưới đồng thời (verified: `OmnichannelChatRepository::syncAccountStaff`). Cân nhắc unique index / `insertOrIgnore` / check-existing để idempotent.
- **Webhook**: idempotent + **KHÔNG downgrade trạng thái mới hơn** do event đến trễ/lặp. Verified guard trong `FriendshipEventHandler` (bỏ qua nếu đã `FRIEND`; chỉ reject từ trạng thái pending). Timestamp webhook dùng `PlatformTime::parse` (§5).

---

## §10. List / pagination

- **Whitelist** `sortBy` & `sortOrder` (chỉ cột cho phép) — verified ở 2 lớp: Validation (`'sortBy' => ['in:...']`) + Repository (`ALLOWED_SORT_COLUMNS` + `in_array`). KHÔNG đưa thẳng input vào `orderBy`.
- LUÔN filter tenant (§8). Escape `% _ \` nếu dùng LIKE cho `search`.
- Tránh N+1: eager load relation cần dùng, chỉ select field cần. List đã theo Spatie QueryBuilder thì giữ pattern đó.

---

## §11. Sửa code có sẵn — giữ behavior (surgical)

- Chỉ sửa phần liên quan yêu cầu. **KHÔNG tự đổi** (trừ khi được yêu cầu): response shape / tên key / status code / message lỗi tiếng Việt / enum value / tên route / queue / Redis connection / schema / migration / public API.
- Phân biệt `null` (FE không gửi field) vs `[]` (gửi rỗng để clear) — đừng đổi `?array` thành `array = []`.
- Thấy vấn đề **ngoài phạm vi** → nêu ra, KHÔNG tự sửa.
- Thiếu thông tin có thể làm **đổi behavior** (null = clear? empty = xóa hết? API fail có retry?) → **HỎI trước khi sửa**.
