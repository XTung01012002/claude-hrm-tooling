# PROMPT: Sinh tài liệu API cho Frontend (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/api-docs`. Với AI khác: dán file này + chỉ định Controller/endpoint cần viết docs.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` §0 (cấm bịa) và §3 (envelope response/lỗi).

## Nhiệm vụ
Viết tài liệu **contract-only cho FE** của (các) endpoint mới/đổi, ghi **1 file/endpoint** vào `api-docs/<Module>/<Endpoint>.md` (vd `api-docs/OmnichannelChat/SendFriendRequest.md`). Cập nhật `api-docs/README.md` (mục lục) nếu thêm file mới.

`api-docs/` **chỉ chứa hợp đồng gọi API cho FE** — KHÁC `docs/` (tài liệu logic nội bộ có sơ đồ luồng/classes liên quan). Tuyệt đối không đưa logic nội bộ vào `api-docs/`.

## Bắt buộc — lấy mọi thứ từ CODE THẬT (cấm bịa)
Đọc theo chuỗi và trích đúng:
1. **Controller** (`source/src/Presentation/API/Controllers/<Module>/<X>Controller.php`): lấy HTTP method + path từ attribute `#[Get(...)]`/`#[Post(...)]`; xem có middleware auth không.
2. **Đường dẫn đầy đủ** = prefix `api/v1` (khai ở `source/config/route-attributes.php`) + path trong attribute. Verify (trong Docker, sau khi artisan chạy): `php artisan route:list --path=<...>`. KHÔNG tự ghép/đoán path.
3. **Command/Query** (`Core/Components/<Module>/<Feature>/<Feature>Command|Query.php`): các field FE truyền (bỏ field hệ thống như `companyId` — backend tự lấy từ token).
4. **Validation _implementation_** (`source/src/Infrastructure/<Module>/Validations/<Feature>Validation.php` — KHÔNG phải `*ValidationInterface` vốn rỗng rule; tìm impl qua binding ở `<Module>ServiceProvider` hoặc theo tên `<Feature>Validation`): lấy `required`/`nullable`/`max`/kiểu để điền cột "Bắt buộc" và ràng buộc.
5. **Handler** (`<Feature>Handler.php`): lấy shape return + liệt kê các nhánh `BusinessException(message, httpCode)` cho bảng Lỗi.
6. **Resource/Mapper/Presenter ở Controller**: nếu Controller bọc kết quả qua Resource/Mapper trước khi trả (vd `ListZaloContactsController` dùng `ListResource::fromPaginator()->toArray()`; có `ZaloContactMapper`, `ChatMessageMapper`...), **lấy shape response theo lớp đó**, KHÔNG lấy thẳng Handler return.
7. **Enum**: nếu field là enum (vd `FriendshipStatusEnum`), liệt kê đúng các giá trị thật.

## Khuôn FE contract-only (theo đúng mẫu này)
```markdown
# <Tên API dễ hiểu bằng tiếng Việt>

`METHOD /api/v1/<đường-dẫn-đầy-đủ>`
**Auth:** Bearer token (nếu có middleware auth)

<1 dòng mô tả mục đích.>

## Request
<chọn "Query params" hoặc "Request body" cho đúng>

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| ... | ... | ✅/❌ | ... |   (required/max lấy từ <Feature>Validation impl)

```json
// payload mẫu (giá trị thật/hợp lý; bỏ field hệ thống)
```

## Response 200
```json
// shape theo Resource/Mapper nếu Controller có bọc; nếu không thì Handler return gói trong envelope:
// detail/action: { "data": {...}, "status": "success", "code": 200, "message": "..." }
// list:          { "data": [...], "links": {...}, "meta": {...}, "status": "success", "code": 200, "message": "..." }
```

<nếu có field enum: liệt kê giá trị, 1 dòng. vd: `friendshipStatus`: NONE | REQUEST_SENT | REQUEST_RECEIVED | REJECTED | FRIEND>

## Lỗi
| HTTP | message | Khi nào |
|---|---|---|
| ... | ... | ... |   (BusinessException trong Handler + 422 validation)
```

## Envelope lỗi (global — ở `source/bootstrap/app.php`, KHÔNG nằm trong Controller)
- Validation fail → **422**: `{ "status": "error", "code": 422, "message": <lỗi đầu tiên>, "errors": { "<field>": "<message>" } }` (field/message lấy từ `<Feature>Validation` impl).
- `BusinessException` → `{ "status": "error", "code": <httpCode>, "message": "...", "errors"?: {...} }` (`code` = httpCode đặt trong Handler).
- 404 (không tìm thấy), 401 (chưa auth), 403 (không quyền), 500 (lỗi hệ thống) — chỉ liệt kê khi endpoint thực sự có thể trả.

## Văn phong (ngắn gọn, đúng ý, không thừa)
- Bảng = giải nghĩa field; JSON mẫu = minh họa shape. **Không lặp** mô tả field ở nhiều nơi.
- **KHÔNG** thêm sơ đồ luồng / "classes liên quan" / các bước xử lý nội bộ (đó là việc của `docs/`).
- Tiếng Việt, đi thẳng vào việc FE cần để gọi API.
- Nếu một field không thấy trong code → **không** đưa vào docs.
