# PROMPT: Sinh unit test (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/scaffold-test <đường-dẫn-class>`. Với AI khác: dán file này + nội dung class cần test.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` §6 (test) và §0 (cấm bịa).

## Nhiệm vụ
Sinh unit test PHPUnit + Mockery cho class được chỉ định (thường là `*Handler`), đặt tại `source/tests/Unit/<ClassName>Test.php`.

## Bắt buộc (bám code thật)
1. **Đọc class thật** trước khi viết: lấy đúng signature constructor (các interface dependency), đúng tên method, đúng kiểu tham số/return. KHÔNG bịa method hay dependency.
2. Mock **mọi** dependency interface bằng `Mockery::mock(<Interface>::class)`. Đọc cả interface để mock đúng method/đối số.
3. Phủ tối thiểu:
   - **Happy path**: validate pass → repo/api trả giá trị hợp lệ → assert mảng return đúng (`self::assertSame(...)`).
   - **Mỗi nhánh `BusinessException`** trong Handler: dựng điều kiện kích hoạt, assert đúng message + httpCode (`$e->getCode()`), và `errors` nếu có.
   - Nhánh validate fail (nếu cần): mock `validate()` ném `ValidationException`.

## Khuôn test (theo file mẫu thật `tests/Unit/GetFriendStatusHandlerTest.php`)
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
        // ... mock repo/api theo đúng method thật

        // Act
        $handler = new <ClassName>($validation, /* ...deps */);
        $result = $handler->handle($command);

        // Assert
        self::assertSame([/* shape thật */], $result);
    }
}
```

## Lưu ý
- Tên test snake_case: `test_<scenario>_<expected_outcome>`.
- `tearDown()` luôn `Mockery::close()`; nếu mock thời gian thì thêm `Carbon::setTestNow();`.
- Chạy kiểm chứng bằng Docker/PHP 8.2: `make ai-test TEST=tests/Unit/<ClassName>Test.php`. (Feature test cần boot app → vẫn chạy qua Docker.)
- Nếu không chắc shape return của Handler → đọc lại Handler, đừng đoán.
