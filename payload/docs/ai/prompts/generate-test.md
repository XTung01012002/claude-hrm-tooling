# PROMPT: Sinh unit test (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/scaffold-test <đường-dẫn-class>`. Với AI khác: dán file này + nội dung class cần test.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` §6 (test) và §0 (cấm bịa).

## Nhiệm vụ

Sinh unit test PHPUnit + Mockery cho class theo **đường dẫn do người dùng chỉ định**. Nếu chưa có đường dẫn class, hãy hỏi lại; không tự chọn class từ `git diff`.

Mặc định đặt test tại `source/tests/Unit/<ClassName>Test.php`, theo convention hiện tại của dự án. Trước khi tạo file, tìm test cùng tên:

- Nếu file đã test đúng FQCN được chỉ định, đọc toàn bộ rồi thêm/cập nhật test liên quan; giữ lại test, helper và ghi chú thủ công vẫn đúng. Không ghi đè mù toàn bộ file.
- Nếu cùng short class name nhưng là FQCN khác, kiểm tra `autoload-dev` và cấu trúc test hiện có rồi dùng `source/tests/Unit/<Module>/<ClassName>Test.php` với namespace tương ứng. Nếu không xác minh được namespace hợp lệ, hỏi người dùng thay vì đoán.

## Chọn chiến lược theo loại class

- Với `*Handler` theo pattern Handler + Validation, dùng khuôn bên dưới và gọi đúng `handle()`/method thật.
- Với Mapper, Service, Value Object, readonly class hoặc loại class khác, suy ra test từ constructor và public method thật. Không ép `validate()`, `$command` hay cấu trúc Handler vào class không có các thành phần đó.
- Chỉ test behavior public. Không gọi private/protected method trực tiếp; phủ chúng thông qua nhánh public tương ứng.

## Bắt buộc — bám code thật

1. **Đọc class thật** trước khi viết: lấy đúng FQCN, constructor, dependency, public method, kiểu tham số/return và mọi nhánh điều kiện. KHÔNG bịa method hay dependency.
2. **Đọc contract và kiểu dữ liệu liên quan**: interface của dependency, Command/Query, DTO, enum, Value Object và class return để dựng đúng đối số và assertion.
3. **Mock đúng đối tượng**:
   - Chỉ mock các collaborator được inject dưới dạng interface như validation, repository, external API, cache hoặc dispatcher: `Mockery::mock(<Interface>::class)`.
   - Command/Query, DTO, enum, Value Object và readonly data object phải được khởi tạo thật bằng giá trị hợp lệ; không mock các đối tượng dữ liệu này.
   - Với concrete dependency khác, bám pattern test sẵn có và chỉ mock khi thật sự là collaborator có side effect; không mặc định mock mọi class.
4. **Trace nhánh nghiệp vụ** trong class đang test và các class/method concrete mà nó gọi trực tiếp, tối đa **2 tầng lời gọi tính từ class đang test**. Nếu gọi qua interface, đọc interface và binding/implementation để hiểu contract, nhưng:
   - Test exception ở dependency thông qua class hiện tại khi class có catch, chuyển đổi hoặc behavior riêng đối với exception đó.
   - Không tạo test chỉ để mock dependency ném exception rồi xác nhận exception truyền nguyên vẹn; behavior đó thuộc unit test của implementation dependency.

## Phạm vi test tối thiểu

- Mỗi happy path hoặc nhánh `if`/`else` trả kết quả thành công khác nhau, bao gồm nhánh theo enum/trạng thái.
- Mỗi `BusinessException` có thể kích hoạt trong phạm vi unit của class: dựng đúng điều kiện, assert message, HTTP code (`$e->getCode()`) và `errors` nếu có.
- Validation fail nếu class thật gọi validation: mock `validate()` ném `ValidationException` và assert behavior thật.
- Tương tác quan trọng với dependency: dùng `once()`, `with(...)`, `andReturn(...)`; dùng `shouldNotReceive(...)` cho dependency không được phép gọi ở nhánh dừng sớm.
- Nếu class dispatch event/job:
  - Qua dispatcher interface: mock và assert đúng event/job, đối số và số lần dispatch.
  - Qua Laravel facade: chỉ dùng `Event::fake()`/`Queue::fake()` khi test boot ứng dụng bằng `Tests\TestCase`; không ép facade fake vào pure unit test không boot app.
  - Assert không dispatch ở nhánh lỗi nếu code yêu cầu như vậy.

### Bước 0 — Chọn Test Strategy Profile

Trước khi duyệt matrix, **chọn profile phù hợp** để không tốn token cho nhóm không liên quan:

| Profile | Áp dụng cho | Nhóm test (số thứ tự) |
|---|---|---|
| **A — Pure logic** | Mapper, DTO, Value Object, Service thuần, Enum | 1, 2, 3, 12, 14 |
| **B — Persistence/API** | Handler có repo/external API, Query | A + 4, 5, 10, 11 |
| **C — Event-driven/Critical** | Queue, webhook, concurrent, transaction, dispatch | Toàn bộ 14 nhóm |

AI chọn profile + giải thích 1 dòng. Sau đó **chỉ duyệt các nhóm trong profile đã chọn**.

### Test Matrix 14 nhóm (duyệt theo profile đã chọn)

Với mỗi nhóm **thuộc profile**: xác nhận có áp dụng không. Nếu có → viết test. Nếu không → ghi "N/A — lý do".

| # | Nhóm | Mô tả | Ví dụ |
|---|---|---|---|
| 1 | **Happy path** | Dữ liệu hợp lệ, hành vi bình thường | validate pass → repo trả đúng → assert return đúng shape |
| 2 | **Boundary** | Giá trị biên: 0, 1, max, min, rỗng, null | Mảng rỗng, chuỗi empty, ID = 0 |
| 3 | **Invalid input** | Sai type, sai format, thiếu field | validate ném ValidationException |
| 4 | **Authorization** | Không có quyền, sai company, sai owner | company_id không match → BusinessException 403 |
| 5 | **State transition** | Trạng thái cũ/mới không hợp lệ | Đổi status từ COMPLETED → PENDING |
| 6 | **Duplicate / Idempotent** | Cùng request gửi lại | Friend request đã tồn tại |
| 7 | **Out-of-order** | Event cũ đến sau event mới | Webhook timestamp cũ hơn record |
| 8 | **Concurrency** | Hai request xử lý cùng bản ghi | lockForUpdate / race condition |
| 9 | **Transaction** | Lỗi giữa chừng phải rollback | Exception sau khi đã ghi 1 bảng |
| 10 | **External API** | Timeout, 4xx, 5xx, response thiếu field | Zalo API trả 500 → BusinessException |
| 11 | **Database** | Record tồn tại / không tồn tại / soft-deleted | findContact trả null → 404 |
| 12 | **Compatibility** | Dữ liệu cũ / format legacy | Field nullable trong DB cũ |
| 13 | **Side effects** | Event, notification, queue, logging | shouldReceive('dispatch')->once() |
| 14 | **Time** | Timezone, quá hạn, thời điểm bằng nhau | Carbon::setTestNow(); deadline hết hạn |

> Nhóm nào không áp dụng thì bỏ qua — không ép viết test vô nghĩa.

## Khởi tạo input và assert output

- Khởi tạo instance thật của Command/Query/DTO trong phần Arrange bằng đúng constructor hoặc factory thật (`fromRequest()` chỉ khi test chính factory đó). Dùng giá trị hợp lý và đúng enum/type; không thay bằng mảng generic.
- Assert theo return type thật:
  - Mảng, scalar hoặc enum: ưu tiên `self::assertSame()`.
  - Object/DTO/Value Object: `assertInstanceOf()` và assert các property/getter thuộc contract; dùng `assertEquals()` khi value equality của object là điều cần kiểm tra.
  - `void`: assert interaction, state hoặc side effect quan sát được thay vì bịa return value.

## Khuôn test cho Handler

Theo file mẫu thật `tests/Unit/GetFriendStatusHandlerTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit;

use Mockery;
use PHPUnit\Framework\TestCase;
// ... use các interface/command/enum THẬT

class <ClassName>Test extends TestCase
{
    protected function tearDown(): void
    {
        Mockery::close();
        parent::tearDown();
    }

    public function test_<scenario>_<expected_outcome>(): void
    {
        // Arrange
        $validation = Mockery::mock(<ValidationInterface>::class);
        $validation->shouldReceive('validate')->once();
        $command = new <Command>(/* giá trị thật, hợp lệ */);
        // ... mock repo/api theo đúng method và đối số thật

        // Act
        $handler = new <ClassName>($validation, /* ...deps */);
        $result = $handler->handle($command);

        // Assert
        self::assertSame(/* giá trị/shape return thật */, $result);
    }
}
```

## Kiểm chứng bắt buộc

1. Chạy test trong Docker/PHP 8.2: `AI_TEST=<đường-dẫn-tương-đối-từ-source> make -f Makefile.ai ai-test`, ví dụ `AI_TEST=tests/Unit/<ClassName>Test.php make -f Makefile.ai ai-test`. Feature test cần boot app vẫn phải chạy qua Docker.
2. Nếu test fail do test vừa sinh, đọc lỗi, sửa nguyên nhân và chạy lại; tối đa **3 lần chạy tổng cộng**.
3. Không nới lỏng/xóa assertion, bỏ test case hoặc sửa production code chỉ để test xanh. Chỉ sửa production code khi người dùng yêu cầu riêng.
4. Nếu vẫn fail sau 3 lần, hoặc Docker/container không sẵn sàng, báo rõ lệnh đã chạy, lỗi cụ thể và trạng thái chưa verify; không chạy PHP/PHPUnit trên host để thay thế và không tuyên bố test đã pass.

## Lưu ý

- Tên test snake_case: `test_<scenario>_<expected_outcome>`.
- `tearDown()` luôn gọi `Mockery::close()`; nếu mock thời gian thì reset bằng `Carbon::setTestNow()` trước `parent::tearDown()`.
- Nếu chưa chắc input, nhánh xử lý hoặc return type, đọc lại code liên quan; không đoán.
