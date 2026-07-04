# Generate Feature

> Nguồn chân lý: `docs/ai/PROJECT-CONVENTIONS.md` (§3)

Nhiệm vụ của bạn là tạo một feature hoàn chỉnh dựa trên cấu trúc chuẩn của dự án (Command/Query, Handler, ValidationInterface).

**Quy tắc bắt buộc:**
1. **Command / Query**:
   - Khai báo biến properties là `public readonly` (theo §3 DTO).
   - Hàm `fromRequest()` dùng để lấy biến, trong đó luôn gán `companyId` từ token / current session nếu feature yêu cầu authentication.
   - **Tên biến/property (input/output)**: LUÔN dùng `camelCase`, KHÔNG dùng `snake_case`.

2. **ValidationInterface**:
   - Chỉ tạo interface đóng vai trò contract với hàm `validate(<Command>): void` (hoặc method có tham số Command tương ứng).
   - Lưu ý: KHÔNG trả về mảng rules ở interface này. Phần rules thực tế sẽ được định nghĩa ở class implement nằm trong `Infrastructure/<Module>/Validations/<Feature>Validation.php` (hãy sinh ra class này hoặc nhắc người dùng tạo).

3. **Handler**:
   - Cần khai báo `declare(strict_types=1);` và class `readonly` (trừ khi kế thừa property Job abstract từ `source/app`).
   - Gọi `validate()` (ValidationInterface) đầu tiên.
   - Return type hint phải là `array` nếu đây là HTTP Response, tuân thủ Response Envelope.
   - Throw `BusinessException` với message cho người dùng theo pattern i18n thật của module (`trans()`/`__()` hoặc tiếng Việt hard-code legacy) và `httpCode` phù hợp khi gặp lỗi logic; KHÔNG bịa translation key.
   - Inject dependencies thông qua constructor.

4. **Khai báo route / ServiceProvider**:
   - Nhắc người dùng bind ValidationInterface trong ServiceProvider của module đó.
   - Nhắc khai báo route nếu cần thiết.

Hãy tạo code cho Module và Feature được yêu cầu (hãy neo vào golden template `SaveZaloAccountStaff` để tham khảo nếu có sẵn). Sau khi sinh code xong, hãy chạy lệnh sau để tự động xác thực cú pháp:
`make -f Makefile.ai ai-lint FILE=source/...`
