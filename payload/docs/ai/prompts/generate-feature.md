# Generate Feature

> Nguồn chân lý: `docs/ai/PROJECT-CONVENTIONS.md` (§3)

Nhiệm vụ của bạn là tạo **core application-layer skeleton** (khung cơ sở) cho một feature dựa trên cấu trúc chuẩn của dự án. Khung này bao gồm: Command/Query, Handler, và ValidationInterface. Khung này sẽ là nền tảng để tiếp tục phát triển (implement) chi tiết.

**Quy tắc bắt buộc:**
1. **Command / Query**:
   - Khai báo biến properties là `public readonly` (theo §3 DTO).
   - Hàm `fromRequest()` dùng để lấy biến, trong đó luôn gán `companyId` từ token / current session nếu feature yêu cầu authentication.
   - **Tên biến/property (input/output)**: LUÔN dùng `camelCase`, KHÔNG dùng `snake_case`.

2. **ValidationInterface**:
   - Chỉ tạo interface đóng vai trò contract với hàm `validate(<Command>): void` (hoặc method có tham số Command tương ứng).
   - Lưu ý: KHÔNG trả về mảng rules ở interface này. Phần rules thực tế sẽ được định nghĩa ở class implement nằm trong `Infrastructure/<Module>/Validations/<Feature>Validation.php` (KHÔNG được tự sinh class implementation này).
3. **Handler**:
   - Cần khai báo `declare(strict_types=1);` và class `readonly` (trừ khi kế thừa property Job abstract từ `source/app`).
   - Gọi `validate()` (ValidationInterface) đầu tiên.
   - Return type hint phải là `array` nếu đây là HTTP Response, tuân thủ Response Envelope.
   - Throw `BusinessException` với message cho người dùng theo pattern i18n thật của module (`trans()`/`__()` hoặc tiếng Việt hard-code legacy) và `httpCode` phù hợp khi gặp lỗi logic; KHÔNG bịa translation key.
   - Inject dependencies thông qua constructor.

4. **Ranh giới công việc (Boundary)**:
   - Không tạo Validation implementation, route, Controller hoặc ServiceProvider binding trong command này.
   - Không được tuyên bố feature đã hoàn chỉnh hoặc có thể chạy end-to-end.

Sau phần code, xuất mục `Next integration steps` gồm:
- Validation implementation cần tạo.
- ServiceProvider binding cần thêm.
- Route/Controller cần thêm nếu feature được expose qua HTTP.
- Test cần tạo.

Sau khi sinh code xong, hãy chạy lệnh sau để tự động xác thực cú pháp:
`AI_FILE=source/... make -f Makefile.ai ai-lint`
