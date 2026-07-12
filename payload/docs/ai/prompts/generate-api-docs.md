# PROMPT: Sinh tài liệu API cho Frontend (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/api-docs`. Với AI khác: dán file này + chỉ định Controller/endpoint cần viết docs.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` §0 (cấm bịa) và §3 (envelope response/lỗi).

## Nhiệm vụ

Viết tài liệu **contract-only cho FE** của (các) Controller/endpoint mới hoặc thay đổi **do người dùng chỉ định**, ghi **1 file/endpoint** vào `api-docs/<Module>/<Endpoint>.md`. Nếu người dùng chưa chỉ định Controller/endpoint, hãy hỏi lại; **không tự suy phạm vi từ `git diff`**.

Quy tắc đặt tên file: lấy `<Module>` từ thư mục chứa Controller; lấy `<Endpoint>` từ tên class Controller sau khi bỏ hậu tố `Controller`. Ví dụ: `OmnichannelChat/SendFriendRequestController.php` → `api-docs/OmnichannelChat/SendFriendRequest.md`. Cập nhật `api-docs/README.md` (mục lục) nếu thêm file mới.

Nếu file tài liệu đã tồn tại, đọc toàn bộ file rồi chỉ cập nhật các phần bị ảnh hưởng theo code hiện tại. Giữ lại ghi chú thủ công nếu vẫn chính xác và thuộc phạm vi contract FE; sửa hoặc loại bỏ nội dung đã lỗi thời/mâu thuẫn với code. Không ghi đè mù toàn bộ file.

`api-docs/` **chỉ chứa hợp đồng gọi API cho FE** — KHÁC `docs/` (tài liệu logic nội bộ có sơ đồ luồng/classes liên quan). Tuyệt đối không đưa logic nội bộ vào `api-docs/`.

## Bắt buộc — lấy mọi thứ từ CODE THẬT (cấm bịa)

Đọc theo chuỗi và trích đúng:

1. **Controller** (`source/src/Presentation/API/Controllers/<Module>/<X>Controller.php`): lấy HTTP method + path từ attribute `#[Get(...)]`/`#[Post(...)]`; xem có middleware auth không.
2. **Đường dẫn đầy đủ**: đọc chính xác prefix `api/v1` trong `source/config/route-attributes.php` và path trong attribute, sau đó verify bằng Docker: `make -f Makefile.ai ai-artisan CMD="route:list --path=<...>"`. Nếu lệnh lỗi hoặc container chưa sẵn sàng, vẫn có thể dùng đường dẫn suy ra từ đúng hai giá trị trong code, nhưng phải cảnh báo người dùng rằng route chưa được verify và nêu lỗi lệnh; không tự đoán thêm prefix/path khác.
3. **Command/Query** (`Core/Components/<Module>/<Feature>/<Feature>Command|Query.php`): các field FE truyền (bỏ field hệ thống như `companyId` — backend tự lấy từ token).
4. **Validation _implementation_** (`source/src/Infrastructure/<Module>/Validations/<Feature>Validation.php` — KHÔNG phải `*ValidationInterface` vốn rỗng rule; tìm impl qua binding ở `<Module>ServiceProvider` hoặc theo tên `<Feature>Validation`): trích **đầy đủ mọi rule ảnh hưởng đến contract**, gồm nhưng không giới hạn `required`, `nullable`, kiểu dữ liệu, `min`, `max`, `email`, `in`, `exists`, `array`, `date`, `boolean` và custom rule class. Dùng cả rule lẫn validation message thật để điền "Bắt buộc", kiểu, ràng buộc và lỗi 422.
5. **Handler và nhánh lỗi có thể đi tới** (`<Feature>Handler.php`): lấy shape return; liệt kê `BusinessException(message, httpCode)` và exception HTTP cụ thể trong Handler. Trace tiếp các class/method mà Handler gọi trực tiếp, tối đa **2 tầng lời gọi tính từ Handler**; nếu gọi qua interface thì tìm implementation qua binding. Chỉ ghi lỗi có nhánh code đi tới được trong phạm vi này, không suy diễn lỗi từ toàn bộ codebase.
6. **Resource/Mapper/Presenter ở Controller**: nếu Controller bọc kết quả qua Resource/Mapper trước khi trả (vd `ListZaloContactsController` dùng `ListResource::fromPaginator()->toArray()`; có `ZaloContactMapper`, `ChatMessageMapper`...), **lấy shape response theo lớp đó**, KHÔNG lấy thẳng Handler return.
7. **Enum**: nếu field là enum (vd `FriendshipStatusEnum`), liệt kê đúng các giá trị thật.

## Quy tắc chọn response envelope

- Nếu Controller dùng Resource/Mapper/Presenter thì shape của lớp đó là nguồn sự thật cao nhất.
- Nếu không có lớp bọc: Query trả `Paginator`/collection dùng envelope **list**; Query trả một item hoặc Command/action dùng envelope **detail/action**.
- Không thêm `links`, `meta` hoặc field response nếu code/envelope thực tế không sinh ra chúng.

## Khuôn FE contract-only (theo đúng mẫu này)

````markdown
# <Tên API dễ hiểu bằng tiếng Việt>

`METHOD /api/v1/<đường-dẫn-đầy-đủ>`
**Auth:** Bearer token (nếu có middleware auth)

<1 dòng mô tả mục đích.>

## Request

<chọn "Query params" hoặc "Request body" cho đúng>

| Trường | Kiểu | Bắt buộc | Mô tả |
| ------ | ---- | -------- | ----- | ----------------------------------------------- |
| ...    | ...  | ✅/❌    | ...   | (mọi ràng buộc lấy từ <Feature>Validation impl) |

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
| ---- | ------- | ------- | ----------------------------------------------------- |
| ...  | ...     | ...     | (validation + exception trong phạm vi trace quy định) |
````

## Envelope lỗi (global — ở `source/bootstrap/app.php`, KHÔNG nằm trong Controller)

- Validation fail → **422**: `{ "status": "error", "code": 422, "message": <lỗi đầu tiên>, "errors": { "<field>": "<message>" } }` (field/message lấy từ `<Feature>Validation` impl).
- `BusinessException` → `{ "status": "error", "code": <httpCode>, "message": "...", "errors"?: {...} }` (`code` = httpCode trong nhánh code đã trace).

Chỉ liệt kê mã lỗi khi có tín hiệu code tương ứng:

- **401**: route/Controller có middleware auth.
- **403**: có middleware phân quyền, Policy/Gate/permission check hoặc exception mã 403 trong phạm vi trace.
- **404**: có `findOrFail`/`firstOrFail`, lookup ném lỗi not-found hoặc exception mã 404 trong phạm vi trace.
- **422**: endpoint chạy validation implementation hoặc có exception mã 422 trong phạm vi trace.
- **500**: chỉ khi có nhánh exception được map rõ thành 500; không thêm lỗi hệ thống chung theo phỏng đoán.

## Lưu ý cho Frontend (BẮT BUỘC)

Sau mục "Lỗi", **luôn thêm mục "Lưu ý cho Frontend"** nếu có bất kỳ điểm nào áp dụng:

```markdown
## Lưu ý cho Frontend
- **Field nullable**: <liệt kê field có thể trả `null` — đọc từ Migration/Model `$casts`/Mapper>
- **Field có thể thiếu**: <field không luôn có mặt trong response — vd chỉ xuất hiện khi điều kiện X>
- **Enum values**: <field> có thể là: `VALUE_1` | `VALUE_2` | ... (đọc từ Enum class thật)
- **Idempotency**: <gọi lại API này có an toàn không? Kết quả có thay đổi?>
- **Reload sau khi gọi**: <FE có cần reload/refetch data sau khi gọi API này không?>
- **Response = final hay queued**: <data trả về là trạng thái cuối cùng hay chỉ là "đã tiếp nhận"?>
- **Timezone**: <thời gian trả về là UTC hay local? Format nào?>
- **Retry**: <error nào nên retry (5xx, timeout)? Error nào KHÔNG nên retry (4xx)?>
- **Hiển thị lỗi**: <message lỗi nào hiển thị trực tiếp cho user? Cái nào cần FE tự xử lý?>
- **Side effects**: <API này có trigger thêm gì không: notification, event WS, email, queue job?>
```

> Chỉ liệt kê mục nào **thật sự áp dụng** cho endpoint cụ thể (đọc code xác nhận). Không liệt kê mục generic "cho có".

## Ví dụ gọi API (TÙY CHỌN — thêm khi logic phức tạp)

Nếu endpoint có logic khó hiểu hoặc flow nhiều bước, thêm ví dụ curl + hướng dẫn xử lý phía FE. Endpoint CRUD đơn giản không cần.

## Văn phong (ngắn gọn, đúng ý, không thừa)

- Bảng = giải nghĩa field; JSON mẫu = minh họa shape. **Không lặp** mô tả field ở nhiều nơi.
- **KHÔNG** thêm sơ đồ luồng / "classes liên quan" / các bước xử lý nội bộ (đó là việc của `docs/`).
- Tiếng Việt, đi thẳng vào việc FE cần để gọi API.
- Nếu một field không thấy trong code → **không** đưa vào docs.
