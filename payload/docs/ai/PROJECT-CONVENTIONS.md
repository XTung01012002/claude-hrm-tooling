# PROJECT CONVENTIONS — HRM API (Gopany)

> **Tài liệu trung lập (AI-agnostic).** Đưa file này cho bất kỳ AI nào (Claude / ChatGPT / Cursor / Copilot / Gemini) trước khi nhờ code/review/viết docs. Nội dung được rút ra & **verify từ code thật** trong `source/`, không phải quy ước lý thuyết.
>
> Lớp tiện ích Claude (`CLAUDE.md`, `.claude/commands/*`, `.claude/hooks/*`) chỉ **trỏ về** file này — đây mới là nguồn chân lý.
>
> **Last fully verified:** 2026-07-03 · HRM source `dev@fe0feba14c11388da1bbd09108b3f60128b16514`. Các giá trị cấu hình và ngoại lệ legacy là **snapshot**, xem §12; luôn re-verify trước khi dựa vào chúng.
>
> **Phạm vi:** kiến trúc, code, API contract, test và runtime của HRM API. Git branch/commit/PR workflow theo quy định của team hoặc prompt `commit-message.md`, không thuộc tài liệu này.

---

## §0. Nguyên tắc nền tảng — BÁM SÁT CODE THẬT, KHÔNG BỊA

**Đây là quy tắc số 1, đứng trên mọi quy tắc khác.**

- Trước khi đặt tên biến, class hoặc mô tả nghiệp vụ: **đọc `docs/ai/CONTEXT.md`** để đồng nhất ngôn ngữ domain HRM.
- Trước khi viết/sửa/ghi docs: **đọc file liên quan** và `grep` để xác nhận tên class / method / field / route / enum **thực sự tồn tại**.
- Chỉ dùng interface / method / field **có thật** trong codebase. Không chắc → tra cứu, **không đoán**.
- **Không bịa**: không bịa field response, không bịa rule validate, không bịa endpoint, không bịa giá trị enum.
- Khi review hay viết docs: mỗi khẳng định phải truy được về `file:line` thật. Nếu không kiểm chứng được → nói rõ "chưa kiểm chứng", đừng khẳng định.
- Với thông tin dễ thay đổi (config, version runtime, timeout, danh sách ngoại lệ legacy): đọc lại file nguồn hiện tại; metadata và §12 chỉ là mốc gần nhất, KHÔNG thay thế việc verify.

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
- Ngoại lệ legacy hiện hành được liệt kê ở snapshot §12 để tránh trộn trạng thái tạm thời vào rule kiến trúc. KHÔNG dùng chúng làm khuôn cho code mới.

---

## §3. Convention code

### §3.1. Cấu trúc feature (1 feature = 3 file)

Theo khuôn `SaveZaloAccountStaff/`:

- `<Feature>Command.php` (ghi) / `<Feature>Query.php` (đọc): DTO `readonly`, có `public static function fromRequest(Request $request): self` (lấy `companyId` từ `auth('api')->user()`, ép kiểu input).
- `<Feature>Handler.php`:
  - `declare(strict_types=1);`
  - `readonly class`, constructor inject **interface** (validation, repo, api, cache...).
  - Gọi `$this->validation->validate($command)` **đầu tiên**.
  - Ném lỗi nghiệp vụ dự kiến bằng `BusinessException(<message cho người dùng>, <httpCode>)` (`Gopany\Core\Components\Shared\BusinessException`); cách tạo message theo §3.4.
  - Dùng enum qua `->value` (vd `FriendshipStatusEnum::REJECTED->value`).
  - `handle(...)` trả về `array`.
  - Tách helper `private` có docblock tiếng Việt.
- `<Feature>ValidationInterface.php`: contract `validate(<Command> $command): void`. Impl ở `Infrastructure/<Module>/Validations/<Feature>Validation.php`, bind trong ServiceProvider của module.

### §3.2. Naming Input/Output

- LUÔN dùng `camelCase` cho các trường dữ liệu API (cả input gửi lên và output trả về) cũng như tên biến/property trong DTO (Command/Query), KHÔNG dùng `snake_case`.

### §3.3. Response envelope

Response được định nghĩa ở `source/bootstrap/app.php` + `ApiBaseController`:

- Detail/action thành công: `jsonResponse($data, $message)` → `{ "data": {...}, "status": "success", "code": 200, "message": "..." }`
- List thành công: `jsonResponseMeta($data, $message)` → `{ "data": [...], "links": {...}, "meta": {...}, "status": "success", "code": 200, "message": "..." }`
- Lỗi phổ biến: `{ "status": "error", "code": <http|string>, "message": "...", "errors"?: {...} }`.
  - `ValidationException` → HTTP/code 422, `message` = lỗi đầu tiên, `errors` = `{ field: <message đầu> }`.
  - `BusinessException` → HTTP/code = code đặt khi khởi tạo, kèm `errors` nếu có.
  - `InsufficientResourceException` → HTTP 400, `code: "INSUFFICIENT_RESOURCES"`.
  - `ModelNotFoundException` / `NotFoundHttpException` → HTTP/code 404.
  - **Legacy khác envelope chung:** `UnauthorizedHttpException` trả `status: "Unauthorized"`; `AccessDeniedHttpException` trả `status: "Forbidden"`; lỗi 500 hiện có thêm `error` chứa exception message.
- Khi sửa feature hiện có, giữ nguyên response theo §11. KHÔNG giả định mọi lỗi đều có `status: "error"`; đọc renderer thật. Field `error` của lỗi 500 là behavior legacy, không coi là public contract để nhân rộng và không đưa dữ liệu nhạy cảm vào exception message.

### §3.4. Exception & i18n

- `ValidationException`: lỗi validate input. `BusinessException`: lỗi nghiệp vụ dự kiến cần trả về API với HTTP code rõ ràng.
- `InsufficientResourceException` có renderer riêng. `CloudflareException` / `TechnitiumException` là lỗi tích hợp hạ tầng; KHÔNG dùng thay `BusinessException` cho lỗi nghiệp vụ API và phải kiểm tra boundary catch/render trước khi để exception đi ra ngoài.
- Chỉ tạo custom exception mới khi cần semantics xử lý khác biệt thật sự (renderer, retry/catch hoặc error code ổn định); không tạo chỉ để đổi tên.
- Codebase đang dùng **cả hai** kiểu message: translation (`trans()` / `__()`, file ở `source/lang/vi/`) và tiếng Việt hard-code ở các module legacy. Khi sửa, theo pattern của module/feature hiện tại; module đã dùng translation thì tái sử dụng/thêm key thật, KHÔNG bịa key. Không tự mass-migrate message vì có thể đổi public behavior (§11).

---

## §4. Repository — code mới ưu tiên Eloquent ORM

- Code **mới** hoặc đoạn repo **bạn sửa**: dùng Eloquent Model (`Model::create`, `->update`, `->where`, relationships, `::withTrashed()`...) → cast (`$casts`) tự áp dụng.
- **Tránh** `DB::table()` / `DB::raw()` cho ghi: query-builder bỏ qua cast → MySQL strict ném **1292** khi nhét chuỗi ISO vào cột datetime. Nếu *buộc* dùng query-builder cho cột datetime, truyền `Carbon`, không phải chuỗi ISO.
- Nhiều repository legacy vẫn dùng query-builder; snapshot §12 ghi ví dụ đã verify. Nếu chạm vào thì cân nhắc migrate sang Eloquent hoặc ghi chú lý do; **đừng copy** làm khuôn cho code mới.
- List/filter dùng **Spatie QueryBuilder** (dựa trên Eloquent) là chấp nhận được.

---

## §5. Các "bẫy" đã biết (đã gặp & verify)

- **Timestamp Zalo**: webhook/API trả epoch dạng số (ms hoặc giây) → dùng `Gopany\Core\Components\OmnichannelChat\Shared\PlatformTime::parse()`, KHÔNG `Carbon::parse()` thô (parse sai âm thầm).
- **Carbon 3 signed diff**: `diffIn*()` trả **có dấu** (âm khi đối số ở quá khứ) → dễ hỏng logic so ngưỡng thời gian. Bọc `abs()` nếu cần độ lớn.
- **Cột datetime + query-builder**: xem §4; nhắc lại tại đây vì đây là lỗi runtime MySQL khó phát hiện khi lint.
- **Queue/Horizon**: `retry_after` thuộc queue connection, còn `timeout` thuộc Horizon supervisor và có thể khác theo environment. Trước khi sửa/đánh giá job, đọc cả `config/queue.php` lẫn `config/horizon.php`; luôn giữ `timeout < retry_after` của connection để tránh job chạy trùng. Giá trị hiện tại xem snapshot §12.
- **PHP 8.2 + Job cha abstract**: tránh `readonly` ở property của abstract Job cha — fail unserialize với `SerializesModels` (reflection). Runtime pin hiện tại xem §12.
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

- **Môi trường chuẩn là Docker container `hrm-api`**. Host PHP có thể mới hơn nên **không dùng làm chuẩn verify**; version pin gần nhất ở §12 và phải kiểm tra lại bằng `ai-php-version`.
- **Không chạy trực tiếp trên host**: `php`, `composer`, `php artisan`, `vendor/bin/phpunit`, `vendor/bin/pint` khi kiểm tra code. Host PHP mới hơn có thể lint pass syntax không tương thích PHP 8.2.
- **Lệnh chuẩn cho AI/agent**:
  - Syntax PHP 8.2: `AI_FILE=source/path/to/File.php make -f Makefile.ai ai-lint`
  - Format 1 file: `AI_FILE=source/path/to/File.php make -f Makefile.ai ai-pint`
  - Format + lint 1 file: `AI_FILE=source/path/to/File.php make -f Makefile.ai ai-check`
  - Unit test: `AI_TEST=tests/Unit/XTest.php make -f Makefile.ai ai-test`
  - Route list: `make -f Makefile.ai ai-route-list` hoặc `AI_ROUTE_PATH=api/v1/... make -f Makefile.ai ai-route-list`
  - Migrate status: `make -f Makefile.ai ai-migrate-status`
  - Kiểm PHP container: `make -f Makefile.ai ai-php-version`
- Composer/deps vẫn chạy trong container (`make shell` → `composer install` → `make copy-vendor`) hoặc dùng các target composer sẵn có của `Makefile`.

---

## §8. Multi-tenancy & Security

- Query dữ liệu thuộc tenant **LUÔN** filter `company_id` (+ `omnichannel_account_id` / `store_id` khi dữ liệu thuộc account/store). KHÔNG query chỉ bằng `id` cho dữ liệu tenant → rò rỉ chéo công ty.
  - Verified: mọi method `ZaloContactRepository` pair `company_id` + `omnichannel_account_id` (`findContact`, `paginateContacts`).
  - Sai: `Model::find($id)`. Đúng: `Model::where('company_id', $companyId)->where('id', $id)->first()`.
- KHÔNG log token / secret / signature / payload nhạy cảm.
- Trước khi gọi API ngoài (Zalo): check account tồn tại + đúng `company_id` + `connection_status === CONNECTED`, và validate payload.

---

## §9. Transaction, race condition, cache & webhook

### §9.1. Transaction & race condition

- `DB::transaction()` khi 1 use case ghi **nhiều bảng** cần atomic (vd sync staff: delete + insert + update). KHÔNG bọc transaction cho query đọc đơn giản.
- `lockForUpdate()` cho read-modify-write dưới đồng thời (verified: `OmnichannelChatRepository::syncAccountStaff`). Cân nhắc unique index / `insertOrIgnore` / check-existing để idempotent.

### §9.2. Cache

- Code Core mới ưu tiên inject interface hẹp ở `Shared/` khi cache là dependency nghiệp vụ/cần mock; implementation đặt ở Infrastructure. Direct `Cache` facade trong Core hiện có là legacy, không tự động coi là pattern mới.
- Key phải có namespace rõ và đủ tenant/resource identifier để không đụng chéo công ty. Chọn cache store có chủ đích; idempotency/webhook chạy qua nhiều worker phải dùng shared store phù hợp.
- Mọi entry tạm thời/lock/idempotency key phải có TTL rõ ràng. Với cache dữ liệu không TTL (`rememberForever`), bắt buộc xác định đường invalidation khi dữ liệu thay đổi.
- Phân biệt semantics: lock/idempotency key có thể cần `forget()` khi dispatch thất bại; throttle key có thể cố ý giữ đến hết TTL sau khi thành công. Không xóa cache “cho sạch” nếu làm đổi behavior.

### §9.3. Webhook

- **Webhook**: idempotent + **KHÔNG downgrade trạng thái mới hơn** do event đến trễ/lặp. Verified guard trong `FriendshipEventHandler` (bỏ qua nếu đã `FRIEND`; chỉ reject từ trạng thái pending). Timestamp webhook dùng `PlatformTime::parse` (§5).

---

## §10. List / pagination

- **Whitelist** `sortBy` & `sortOrder` (chỉ cột cho phép) — verified ở 2 lớp: Validation (`'sortBy' => ['in:...']`) + Repository (`ALLOWED_SORT_COLUMNS` + `in_array`). KHÔNG đưa thẳng input vào `orderBy`.
- LUÔN filter tenant (§8). Escape `% _ \` nếu dùng LIKE cho `search`.
- Tránh N+1: eager load relation cần dùng, chỉ select field cần. List đã theo Spatie QueryBuilder thì giữ pattern đó.

---

## §11. Sửa code có sẵn — giữ behavior (surgical)

- Chỉ sửa phần liên quan yêu cầu. **KHÔNG tự đổi** (trừ khi được yêu cầu): response shape / tên key / status code / message lỗi trả cho người dùng / enum value / tên route / queue / Redis connection / schema / migration / public API.
- Phân biệt `null` (FE không gửi field) vs `[]` (gửi rỗng để clear) — đừng đổi `?array` thành `array = []`.
- Thấy vấn đề **ngoài phạm vi** → nêu ra, KHÔNG tự sửa.
- Thiếu thông tin có thể làm **đổi behavior** (null = clear? empty = xóa hết? API fail có retry?) → **HỎI trước khi sửa**.

---

## §12. Snapshot đã verify — PHẢI kiểm tra lại

> Snapshot này phản ánh HRM source `dev@fe0feba14c11388da1bbd09108b3f60128b16514`, verified 2026-07-03. Khi code/config đổi, cập nhật hoặc xóa entry tương ứng. Lịch sử “đã fix ngày nào” để ở Git/CHANGELOG/issue tracker, KHÔNG giữ trong convention đang sống.

- **Legacy layering:** `CreateTagHandler`, `UpdateTagHandler`, `AssignThreadTagsHandler`, `UnassignThreadTagHandler` import trực tiếp `Infrastructure\OmnichannelChat\Mappers\ChatTagMapper`; `OmnichannelPermissionChecker` dùng `Infrastructure\User\Traits\ResolvesUsersByAccountPermissionSubject`.
- **Legacy query-builder:** `OmnichannelChatRepository::syncAccountStaff()` dùng `DB::table('zalo_account_users')` cho delete/insert/update.
- **Queue:** `config/queue.php` có nhiều connection (`sync`, `database`, `beanstalkd`, `sqs`, `redis`), trong đó chỉ một connection dùng driver Redis và có tên `redis`; default `REDIS_QUEUE_RETRY_AFTER` = **700**.
- **Horizon:** production/staging/development dùng connection `redis`, timeout `chat=60`, `chat-heavy=610`, `domain=600`. Local dùng `chat=60`, `chat-heavy=610`; queue `domain` nằm trong `supervisor-default` timeout **120**.
- **Runtime:** Docker image local pin `frankenphp:1.12.3-php8.2.31-trixie-...`; source `composer.json` yêu cầu PHP `^8.2`. Docker daemon không chạy tại lần verify nên version **8.2.31** được xác nhận từ image pin, chưa runtime-probe bằng `php -v`.
- **Custom exception hiện có:** `BusinessException`, `InsufficientResourceException`, `CloudflareException`, `TechnitiumException`.
- **Cache hiện có:** `OmnichannelCacheInterface` chỉ expose `forgetThreadUserAccess()`; một số Core handler vẫn gọi `Cache` facade trực tiếp cho webhook idempotency/throttle — xem §9.2 trước khi viết code mới.
