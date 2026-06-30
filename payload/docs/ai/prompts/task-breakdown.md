# Rule Bẻ Việc - Task Breakdown cho HRM API

> Áp dụng khi user yêu cầu: **bẻ việc**, **bóc task**, **breakdown**, **chia task**, **estimate**, hoặc gửi **User Story / Feature / Code snippet** cần phân tích.

---

# 1. Xác định Scope

## 1.1. Xác định scope trước khi bẻ việc

Trước khi bẻ việc, cần xác định:

- Bẻ việc cho file nào?
- Bẻ việc cho feature/task gì?
- Scope chỉ gồm code được gửi hay gồm cả route/controller/request/job/migration liên quan?

Chỉ hỏi lại khi thiếu thông tin làm thay đổi hoàn toàn phạm vi công việc. Nếu có thể estimate theo giả định hợp lý, ưu tiên làm vậy — xem Mục 1.4.

Ví dụ nên hỏi lại:

- "Tối ưu code này" — không rõ tối ưu phần gì, tiêu chí nào
- "Bóc task module chat" — không rõ module có bao nhiêu feature, FE/BE/cả hai

Ví dụ không cần hỏi lại, estimate theo giả định: xem Mục 1.4.

## 1.2. Không cần hỏi lại nếu scope đã rõ

Nếu user đã gửi rõ:

- File/code snippet cụ thể
- User Story cụ thể
- Scope cụ thể

Thì tiến hành bẻ việc luôn.

Ví dụ:

- "Bẻ việc đoạn code `SendFileMessageHandler.php` này"
- "Bóc task cho User Story: gửi file/media qua hội thoại Zalo"
- "Estimate riêng phần Handler này"

## 1.3. Không tự mở rộng scope

Khi bẻ việc từ file/code snippet cụ thể:

- Chỉ tính logic xuất hiện trong snippet.
- Không tự thêm Route / Controller / Request / Migration / Job implementation nếu chưa được cung cấp.
- Nếu có gọi class khác như `SendOmnichannelFileJob::dispatch(...)`, chỉ tính phần dispatch job, không tính logic xử lý bên trong job.
- Nếu scope là Handler, không tính Router/Controller/Webhook entrypoint là boundary nếu không nằm trong file hoặc không phải phần cần sửa.
- Nếu muốn estimate cả flow end-to-end, phải ghi rõ phần nào nằm ngoài scope và cần bóc riêng.

## 1.4. Ưu tiên estimate theo giả định thay vì hỏi lại quá nhiều

Nếu thiếu codebase hoặc thiếu một phần thông tin nhưng vẫn có thể xác định phạm vi tương đối, phải estimate theo giả định rõ ràng thay vì hỏi lại.

Chỉ hỏi lại khi thiếu thông tin làm thay đổi hoàn toàn phạm vi công việc.

Ví dụ hợp lệ khi estimate theo giả định:

- "Bóc task webhook Zalo" → giả định: scope là backend handler/service, chưa tính controller/request/job implementation
- "Estimate riêng Handler" → tuyệt đối không tự cộng Route/Controller/Migration/Job implementation

Khi estimate theo giả định, phải ghi rõ trong output:

> Scope giả định: {mô tả phạm vi giả định}. Point có thể điều chỉnh sau khi review codebase.

---

# 2. Phân Tích Codebase

Khi có codebase hoặc file liên quan, phân tích:

- `source/src/Core/Components/{Domain}/`
  - Command
  - Query
  - Handler
  - Interface

- `source/src/Infrastructure/{Domain}/`
  - Model
  - Repository
  - Validation
  - Provider
  - Mapper
  - Event

- `source/src/Presentation/API/Controllers/{Domain}/`
  - Controller
  - Resource
  - Route binding

- `source/database/migrations/`
  - Migration liên quan

- Queue / Job / Storage / Helper liên quan nếu có

Cần xác định:

- File nào tạo mới
- File nào cần sửa
- Dependency nào chỉ tái sử dụng
- Dependency nào cần sửa
- Boundary kỹ thuật bị chạm
- Phần nào nằm trong scope
- Phần nào nằm ngoài scope

Nếu không có codebase đầy đủ, phải ghi chú:

> Point ước tính, có thể điều chỉnh sau khi review code thực tế.

## 2.1. Quy tắc dependency trong Handler

Handler chỉ được phụ thuộc vào Interface, không gọi trực tiếp Repository implementation.

- Đúng: `ChatRepositoryInterface`, `ZaloAccountRepositoryInterface`
- Không nên: `ChatRepository`, `ZaloAccountRepository`

Khi estimate:

- Nếu task cần tạo repository mới → phải tính cả Interface + binding trong Provider → ghi vào cột File/Dependency liên quan.
- Nếu chỉ reuse Interface đã có → ghi `(reuse)`.
- Không estimate lại logic bên trong Repository/Job/Event nếu chúng chỉ được gọi lại từ Handler.
- Hệ quả từ phía Handler: khi Handler chỉ gọi lại interface đã có, không cộng điểm cho logic bên trong interface đó; chỉ tính phần xử lý mới quanh lời gọi (xem §6.1).

---

# 3. Tạo Sub-task [DEV]

Tạo 1 output `[DEV]` chứa bảng bẻ việc chi tiết. Nếu có task `[BE]` gốc thì ghi rõ nguồn từ task `[BE]`; nếu không có thì ghi theo scope user cung cấp.

**Trường hợp 1: Có task `[BE]` gốc**

```markdown
## [DEV] {mô tả công việc cụ thể}

> Từ task gốc: [BE] {tên task gốc}
> Scope: {phạm vi estimate}
```

**Trường hợp 2: Chỉ có code snippet, không có task `[BE]`**

```markdown
## [DEV] {Tên file / chức năng được phân tích}

> Từ scope: {mô tả scope user cung cấp}
> Scope: {phạm vi estimate}
```

**Trường hợp 3: Chỉ có User Story, không có task `[BE]` và không có code snippet**

```markdown
## [DEV] {Tên chức năng từ User Story}

> Từ User Story: {nội dung User Story}
> Scope: {phạm vi estimate — ghi rõ giả định vì chưa có code, point có thể điều chỉnh sau khi review codebase}
```

---

# 4. Nguyên Tắc Chia Task

Một task phải:

- Có thể hoàn thành độc lập.
- Có thể test/verify độc lập.
- Có mô tả rõ làm gì, ở đâu, output là gì.
- Không quá nhỏ.
- Không quá lớn.

Output verify phải đủ rõ để người khác kiểm tra được sau khi làm xong, ví dụ:

- Validate trả đúng lỗi.
- DB được cập nhật đúng field.
- Job được dispatch đúng payload.
- Event được bắn đúng data.
- Response trả đúng format.

Không được chia kiểu:

- Tạo 1 file rỗng = 1 task.
- Thêm 1 dòng import = 1 task.
- "Làm toàn bộ module" = 1 task.
- "Xử lý tất cả webhook" = 1 task nếu bên trong có nhiều nhóm logic khác nhau.

Nếu 1 task > 2 Point → **bắt buộc tách nhỏ hơn**.

---

# 5. Chia Theo Technical Boundary

Technical Boundary là ranh giới giữa các tầng kỹ thuật khác nhau.

Các boundary thường gặp:

- HTTP / Controller / Request
- Validation
- Authorization / Permission
- Database Read
- Database Write
- Database Transaction
- File I/O
- S3 / Storage
- Cache
- Message Queue
- Event / Broadcast
- External API
- Webhook
- Logging / Monitoring

## Phân biệt Webhook là boundary hay không

Webhook Handler **chỉ được tính là boundary riêng** nếu trong scope task có xử lý HTTP entrypoint từ bên thứ ba, ví dụ:

- Nhận HTTP request từ bên thứ ba.
- Verify signature, auth hoặc token.
- Parse raw payload từ request.
- Quyết định HTTP response/status trả về cho bên thứ ba, ví dụ `200 OK`, `400 Bad Request`, `401 Unauthorized`.
- Xử lý retry contract với bên thứ ba dựa trên HTTP response.

Nếu scope chỉ là handler mapping/điều phối event đã được nhận sẵn, ví dụ `ChatZaloWebhookHandler.php` chỉ routing theo event type, **không tính Webhook như một boundary riêng**.

Kể cả class có tên `WebhookHandler`, nếu nó không nhận HTTP request trực tiếp, không verify signature/auth, không parse raw payload và không trả HTTP response cho bên thứ ba, thì nên xem nó là application handler / event listener / queue consumer nội bộ thay vì Webhook boundary.

## Rule quan trọng

Không chia task theo số file.

Nếu 1 file/class chạm nhiều boundary thì phải bóc thành nhiều task theo flow xử lý thực tế.

Ví dụ 1 handler xử lý:

```text
Validation → DB Read → File I/O → S3 → DB Write → Queue → Event
```

Không được đánh là 1 task Small chỉ vì nằm trong 1 file.

Nên chia thành:

- Kiểm tra dữ liệu và quyền
- Lấy thông tin nghiệp vụ liên quan
- Upload file lên S3
- Lưu dữ liệu vào database
- Đẩy job vào queue
- Bắn event realtime

> Danh sách trên là minh hoạ. Các boundary kề nhau có logic chung (ví dụ Validation + Permission) được phép gộp thành 1 task — như §18 gộp "Kiểm tra dữ liệu và quyền" — miễn không gộp quá nhiều boundary để hạ point bất thường (§10) và nhãn Size vẫn đúng theo §7.

---

# 6. Rule Tái Sử Dụng Code Có Sẵn

Đây là rule ưu tiên cao.

Phải phân biệt rõ:

- Hàm/class đã có sẵn và chỉ gọi lại
- Hàm/class phải viết mới
- Hàm/class có sẵn nhưng cần sửa
- Không chắc hàm/class đã có hay chưa

## 6.1. Hàm/class đã có sẵn và chỉ gọi lại

Ví dụ:

```php
$this->chatRepo->isUserAssignedToThread(...)
```

Nếu hàm này đã có sẵn và chỉ gọi lại:

- Không tính như viết mới query.
- Giảm effort 1 bậc.
- Có thể gộp vào task liên quan.
- Ghi rõ là `reuse`.

**Làm rõ phạm vi "không tính" khi gọi interface/hàm đã có:**

- Phần KHÔNG tính: logic bên trong interface/hàm cũ đã có sẵn (đã tính ở nơi viết ra nó, hoặc thuộc code có sẵn). Chỉ gọi lại thì coi như 0 point cho phần implementation đó — thống nhất với §2.1.
- Phần VẪN tính: công việc mới bao quanh lời gọi trong task hiện tại (mapping tham số, xử lý kết quả, nhánh lỗi, điều kiện nghiệp vụ). Phần này áp dụng "giảm 1 bậc effort", KHÔNG về 0.
- Nếu một task không còn việc mới nào ngoài việc gọi lại interface cũ (call trần) và < 0.125 Point → gộp vào task liên quan theo §10; không tách thành task riêng và không ghi 0 point cho một task vẫn còn công việc bao quanh.

**Thứ tự ưu tiên khi điều chỉnh do reuse (tránh double-apply):**

- Reuse TOÀN BỘ phần logic chính/implementation đã có (chỉ gọi lại, không viết mới) → giảm 1 bậc effort theo §6.1.
- Reuse phần lớn nhưng vẫn viết thêm một ít → dùng điều chỉnh ±0.125 theo §9.
- Không áp dụng đồng thời cả hai cho cùng một lần reuse. "Giảm point khi reuse nhiều" (§10) là nguyên tắc chung, được cụ thể hóa bằng 2 mức trên.

## 6.2. Hàm/class phải viết mới

Nếu phải tự viết mới:

- Tính đầy đủ theo logic thực tế.
- Tính cả query, validation, edge case, test case liên quan.

## 6.3. Hàm/class có sẵn nhưng cần sửa

Nếu có sẵn nhưng cần sửa logic:

- Chỉ tính phần sửa đổi.
- Không tính lại toàn bộ class như viết mới.

## 6.4. Không chắc đã có hay chưa

Phải ghi rõ:

> Point có thể giảm nếu logic này đã có sẵn và chỉ tái sử dụng.

## 6.5. Tái sử dụng across nhiều file trong cùng một phiên bóc task

Áp dụng khi user gửi NHIỀU file/snippet để bóc trong cùng một phiên và muốn một estimate gộp (một báo giá chung).

- Nguyên tắc không cộng trùng (§10) mở rộng ra nhiều file: nếu logic của một hàm/class đã được tính khi estimate file trước, thì khi file sau gọi lại chính hàm/class đó, KHÔNG tính lại logic bên trong — đánh dấu `(reuse)` và tính 0 cho phần implementation (giống §6.1, §2.1).
- File "sở hữu" điểm là file ĐẦU TIÊN trong thứ tự gửi có viết mới / định nghĩa logic dùng chung đó. Các file sau chỉ gọi lại đều tính là reuse.
- Ở cột File/Dependency và "Lý do point" của file sau, ghi rõ logic này đã được tính ở file nào để người review truy vết được, ví dụ: `XHelper::doThing (reuse — đã tính ở file A, task #2)`.
- NGOẠI LỆ: nếu user yêu cầu estimate từng file như một deliverable độc lập (báo giá riêng từng file), KHÔNG trừ chéo; mỗi file đứng độc lập theo §1.2/§1.3.

---

# 7. Xác Định Size

Size đánh theo Technical Boundary, không đánh theo số file.

| Size  | Tiêu chí                                   | Ví dụ                                                                 |
| ----- | ------------------------------------------ | --------------------------------------------------------------------- |
| **S** | 1 boundary chính, logic gọn, ít dependency | Validate input, check permission, update 1 field DB, dispatch 1 event |
| **M** | 2 boundary hoặc 2 luồng phối hợp           | File I/O + S3, DB Write + Event, HTTP + DB                            |
| **L** | 3 boundary trở lên, nhiều bước điều phối   | HTTP + Validation + DB + S3 + Queue + Event                           |

Số file/method chỉ là dấu hiệu phụ.

- 1 file nhưng cross nhiều boundary → không phải Small.
- Nhiều file CRUD theo pattern có sẵn → chưa chắc là Large.
- 1 job xử lý HTTP download + S3 + DB transaction + fallback → có thể là Large dù chỉ 1 file.

---

# 8. Xác Định Effort

Effort đánh theo độ khó thực tế, rủi ro và edge case.

| Effort | Tiêu chí                                                                    | Ví dụ                                                                    |
| ------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **E**  | Logic đơn giản, pattern sẵn, ít edge case, reuse nhiều                      | CRUD cơ bản, map field, gọi helper/repository có sẵn                     |
| **M**  | Có business logic, validation, xử lý lỗi                                    | Check quyền, kiểm tra trạng thái, mapping attachment, update thread      |
| **H**  | Nhiều edge case, resource handling, async/concurrency, external integration | Stream file, S3 upload, retry, transaction, race condition, external API |

## Tăng effort nếu có

- Legacy code khó hiểu
- Phụ thuộc nhiều module
- Cần research
- Cần test kỹ
- Có resource handling như stream/file descriptor
- Có external service như S3/Zalo API
- Có async flow như Queue/Event
- Có race condition/idempotency/concurrency

## Giảm effort nếu có

- Đã có code mẫu gần giống
- Chỉ gọi lại hàm có sẵn
- Copy-paste và sửa nhẹ
- Task tương tự đã làm nhiều lần
- Không có business logic mới

---

# 9. Ma Trận Point

|                | **Easy (E)** | **Medium (M)** | **Hard (H)** |
| -------------- | -----------: | -------------: | -----------: |
| **Small (S)**  |        0.125 |           0.25 |          0.5 |
| **Medium (M)** |          0.5 |              1 |          1.5 |
| **Large (L)**  |            1 |            1.5 |            2 |

## Điều chỉnh ±0.125

Cho phép điều chỉnh ±0.125 khi task nằm ở ranh giới giữa 2 mức size hoặc effort, và có 1 yếu tố tăng/giảm nhỏ không đủ để đổi tier hoàn toàn.

Ví dụ hợp lệ:

- Task là S/Hard (0.5) nhưng có thêm 1 điều kiện edge case nhỏ → 0.625
- Task là M/Medium (1.0) nhưng reuse được phần lớn logic → 0.875
- Task là M/Hard (1.5) nhưng đã có code mẫu rất gần → 1.375

Không được dùng ±0.125 để inflate/deflate tùy tiện mà không có lý do cụ thể trong cột **Lý do point**.

## Giới hạn trần point

Không được cộng thêm point cho task đã chạm mức tối đa **2 Point**.

- Nếu task đang là **Large/Hard = 2 Point** và có thêm rủi ro nhỏ, vẫn giữ **2 Point** và ghi rõ rủi ro trong cột **Lý do point** hoặc phần **Ghi chú**.
- Nếu phần rủi ro tạo ra một phần việc có thể verify độc lập, phải tách thành task riêng thay vì cộng lên **2.125 Point**.
- Không có task hợp lệ nào được vượt quá **2 Point**.

## Overlap trong ma trận

Một số combination cho cùng giá trị point, ví dụ S/Hard = M/Easy = 0.5. Khi gặp trường hợp này, chọn combination phản ánh đúng bản chất thực tế của task để cột **Lý do point** có ý nghĩa:

- Logic gọn nhưng cần xử lý edge case phức tạp → **S/Hard**
- Logic rộng hơn nhưng đơn giản, nhiều reuse → **M/Easy**

Lựa chọn này không ảnh hưởng point nhưng giúp estimate nhất quán khi nhiều người cùng review.

Point hợp lệ:

```text
0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875,
1, 1.125, 1.25, 1.375, 1.5, 1.625, 1.75, 1.875, 2
```

Khi output estimate cuối cùng, **không được để range point** trong bảng task. Mỗi task phải chốt 1 giá trị point cụ thể. Range chỉ dùng làm tham khảo trong guideline.

Quy đổi:

```text
1 Point = 100.000 VNĐ
0.125 Point = 12.500 VNĐ
```

---

# 10. Nguyên Tắc Công Bằng

- Đánh theo effort thực tế.
- Không inflate để tăng tiền.
- Không deflate để giảm chi phí.
- Nếu phân vân giữa 2 mức → chọn mức thấp hơn.
- Nếu có rủi ro rõ ràng → được tăng point.
- Nếu reuse nhiều → phải giảm point.
- Không tự thêm task ngoài scope.
- Không gộp quá nhiều boundary vào 1 task để làm tổng point thấp bất thường.
- Nếu task > 2 Point → bắt buộc tách nhỏ hơn.
- Nếu task chạm 2 Point và vẫn còn rủi ro tăng thêm → không cộng vượt 2 Point; ưu tiên tách phần có thể verify độc lập. Nếu thật sự không tách được vì là atomic logic, giữ 2 Point và ghi rõ rủi ro trong cột **Lý do point** hoặc phần **Ghi chú**.
- Nếu task < 0.125 Point → gộp vào task liên quan.
- Không cộng trùng point cho cùng một logic ở nhiều task. Ví dụ: nếu task "Lưu tin nhắn" đã tính mapping attachment thì task "Chuẩn hóa payload" chỉ tính phần trước đó, không tính lại mapping DB. Nếu task "Đẩy job" chỉ dispatch thì không cộng thêm logic xử lý bên trong job.
- Nguyên tắc không cộng trùng cũng áp dụng across nhiều file trong cùng một phiên bóc gộp (xem §6.5).

---

# 11. Tên Task

Tên task phải viết bằng tiếng Việt, dễ hiểu cho người khác đọc.

## Nên viết

- Kiểm tra quyền gửi file trong hội thoại
- Lấy thông tin hội thoại và tài khoản Zalo
- Upload file tạm lên S3
- Lưu tin nhắn gửi file vào database
- Đẩy job gửi file sang queue
- Cập nhật hoạt động hội thoại và bắn realtime event

## Không nên viết

- Validate command
- Resolve thread
- Persistence
- Queue dispatch
- Handle event
- Process file

---

# 12. File/Dependency Liên Quan

Mỗi task phải có cột:

```markdown
File/Dependency liên quan
```

Cột này dùng để ghi rõ:

- File chính đang estimate
- File/class cần sửa
- File/class cần tạo mới
- Dependency được gọi lại
- Repository/Event/Job/Helper chỉ reuse

Nếu scope đã cố định là 1 file, cột này **không có nghĩa là mở rộng scope**. Cột này chỉ dùng để ghi file chính đang estimate và các dependency được gọi/reuse/cần sửa/cần confirm.

## Cách ghi

- `{File chính}`: file đang estimate
- `{RepositoryInterface/Event/Job/Helper} (reuse)`: dependency đã có sẵn, chỉ gọi lại
- `{Class/File} (tạo mới)`: cần tạo mới
- `{Class/File} (cần sửa)`: có sẵn nhưng phải sửa
- `{Class/File} (cần confirm)`: chưa chắc đã có hay chưa

Ví dụ:

| Task                                    | File/Dependency liên quan                                                                                                                         |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kiểm tra quyền gửi file trong hội thoại | `SendFileMessageHandler.php`, `SendFileMessageValidationInterface` (reuse), `ChatRepositoryInterface::isUserAssignedToThread` (reuse/cần confirm) |
| Upload file tạm lên S3                  | `SendFileMessageHandler.php`, `Storage::disk('s3')`, `FileManagerHelper` (reuse)                                                                  |
| Đẩy job gửi file sang queue             | `SendFileMessageHandler.php`, `SendOmnichannelFileJob` (reuse, không tính implementation job)                                                     |

---

# 13. Lý Do Point

Mỗi task phải có cột:

```markdown
Lý do point
```

Mục tiêu: người không đọc sâu code vẫn hiểu vì sao task đó được đánh như vậy.

## Cách viết

Nên viết ngắn, rõ, dễ hiểu:

- Điểm này đến từ...
- Đã giảm vì...
- Tăng vì...
- Không tính phần... vì nằm ngoài scope.

Tránh lạm dụng từ khó như:

- boundary
- orchestration
- side-effect
- router

Có thể dùng từ kỹ thuật khi thật sự cần, nhưng phải giải thích dễ hiểu.

## Format khuyến nghị

```text
Điểm này đến từ {khối lượng chính}. Đã giảm vì {phần reuse}. Tăng vì {rủi ro/logic khó nếu có}.
```

Ví dụ:

```text
Có 5 loại event cần xử lý nhưng logic gần giống nhau: tìm account, cập nhật trạng thái và bắn realtime. Repository/Event đã có sẵn nên không tính cao như viết mới toàn bộ.
```

Ví dụ khác:

```text
Point cao vì payload Zalo có nhiều dạng: text, file, link, sticker. Cần chuẩn hóa dữ liệu trước khi lưu và tránh tạo trùng tin nhắn.
```

---

# 14. Format Output Bắt Buộc

Dòng nguồn dùng 1 trong 3 format sau, tùy theo input thực tế:

```markdown
> Từ task gốc: [BE] {tên task gốc}
```

```markdown
> Từ scope: {mô tả scope user cung cấp}
```

```markdown
> Từ User Story: {nội dung User Story}
```

Template output bắt buộc:

```markdown
## [DEV] {Tên công việc}

> {Dòng nguồn phù hợp}
> Scope: {phạm vi estimate}

| #   | Task                          | File/Dependency liên quan | Mô tả                                     | Size  | Effort   | Point       | Lý do point     |
| --- | ----------------------------- | ------------------------- | ----------------------------------------- | ----- | -------- | ----------- | --------------- |
| 1   | {Tên task tiếng Việt dễ hiểu} | {file/dependency}         | {mô tả làm gì, ở đâu, output verify được} | S/M/L | E/M/H    | {số cụ thể} | {lý do dễ hiểu} |
| 2   | ...                           | ...                       | ...                                       | ...   | ...      | ...         | ...             |
|     |                               |                           |                                           |       | **Tổng** | **{tổng}**  |                 |

**Tổng: {tổng} Point = {tổng × 100.000} VNĐ**

Ghi chú:

- {ghi chú nếu có phần ngoài scope}
- {ghi chú nếu point có thể giảm do reuse}
- {ghi chú nếu cần review codebase thực tế}
```

Trong output cuối cùng, cột `Point` phải là **một số cụ thể**, không để range như `0.125 - 0.25`.

---

# 15. Sanity Check Trước Khi Finalize

Trước khi trả kết quả, kiểm tra:

- [ ] Scope đã rõ chưa?
- [ ] Có tự thêm task ngoài scope không?
- [ ] Mỗi task có thể test/verify độc lập không?
- [ ] Task có tên tiếng Việt dễ hiểu không?
- [ ] Có cột File/Dependency liên quan chưa?
- [ ] Có cột Lý do point chưa?
- [ ] Có xét reuse hay viết mới chưa?
- [ ] Size có đánh theo Technical Boundary, không đánh theo số file chưa?
- [ ] Effort có phản ánh đúng business logic, edge case, resource handling không?
- [ ] Không có task nào > 2 Point.
- [ ] Không có task nào < 0.125 Point.
- [ ] Point dùng giá trị hợp lệ.
- [ ] Output cuối không để range point trong từng task.
- [ ] Tổng point hợp lý với scope.
- [ ] Nếu thiếu codebase, đã ghi chú point ước tính chưa?
- [ ] Không có logic nào bị cộng trùng giữa nhiều task không?
- [ ] Handler có phụ thuộc vào Interface, không gọi trực tiếp Repository implementation không?
- [ ] Logic bên trong interface/hàm cũ chỉ-gọi-lại có bị tính lại như viết mới không? (§6.1, §2.1)
- [ ] Nếu bóc nhiều file trong một phiên gộp, logic dùng chung đã tính ở file trước có bị tính lại ở file sau không? (§6.5)

---

# 16. Mapping Kiến Trúc HRM API → Task

Khi bẻ việc cho feature CRUD mới trong HRM API, tham khảo mapping sau.

## 16.1. Feature CRUD đầy đủ

| #   | Task                                       | File/Dependency liên quan                                   | Size | Effort | Point gợi ý  |
| --- | ------------------------------------------ | ----------------------------------------------------------- | ---- | ------ | ------------ |
| 1   | Tạo migration và model                     | `database/migrations`, `{Domain}Model.php`                  | S    | E      | 0.125 - 0.25 |
| 2   | Tạo entity và mapper                       | `{Domain}Entity.php`, `{Domain}Mapper.php`                  | S    | E      | 0.125 - 0.25 |
| 3   | Tạo repository interface và implementation | `{Domain}RepositoryInterface.php`, `{Domain}Repository.php` | M    | M      | 1            |
| 4   | Tạo flow thêm mới dữ liệu                  | Command, Handler, Validation, Controller                    | M    | E      | 0.5          |
| 5   | Tạo flow cập nhật dữ liệu                  | Command, Handler, Validation, Controller                    | M    | E      | 0.5          |
| 6   | Tạo flow xóa dữ liệu                       | Command, Handler, Validation, Controller                    | S    | E      | 0.125 - 0.5  |
| 7   | Tạo flow danh sách và tìm kiếm             | Query, Handler, Controller, SearchFilter                    | M    | M      | 1            |
| 8   | Tạo flow chi tiết dữ liệu                  | Query, Handler, Controller                                  | S    | E      | 0.125 - 0.5  |
| 9   | Đăng ký service provider                   | Provider, `bootstrap/providers.php`                         | S    | E      | 0.125        |

> Lưu ý: Các range trong mục này chỉ dùng để tham khảo nhanh. Khi đưa vào bảng estimate cuối, bắt buộc chọn **1 point cụ thể** theo ma trận Size × Effort (§9); không để range trong cột Point (xem §14).

> Mức 0.125 chỉ dùng khi task gần như theo pattern có sẵn, không có relation phức tạp, không có permission riêng, không có business rule đặc biệt.

> Các point trong bảng CRUD chỉ áp dụng khi project đã có pattern chuẩn, ít business rule, ít relation và phần lớn code có thể reuse/copy theo module tương tự. Nếu có permission, relation phức tạp, validate theo company, transaction hoặc logic nghiệp vụ riêng thì phải tách task hoặc tăng point.

Tổng CRUD cơ bản: **3.625 Point** (tính theo mức thấp nhất của range). Điều chỉnh lên theo business logic thực tế.

---

# 17. Mapping Feature Sửa/Bổ Sung

> ⚠️ Các con số dưới đây là **tổng point ước tính cho cả feature**, không phải cho 1 task đơn lẻ. Mỗi task đơn trong feature đó vẫn phải tuân thủ giới hạn tối đa 2 Point và bắt buộc tách nếu vượt quá.
>
> **Không được đưa trực tiếp các số 3 hoặc 4 Point vào một dòng task.** Nếu feature vượt 2 Point, bắt buộc tách thành nhiều task nhỏ, mỗi task ≤ 2 Point (theo §4, §9 trần point, §10).

| Loại việc                | Scope thường gặp                             | Point tham khảo (cả feature) |
| ------------------------ | -------------------------------------------- | ---------------------------: |
| Thêm field mới           | Migration + Model + Validation + Resource    |                      0.5 - 1 |
| Thêm logic nghiệp vụ nhỏ | Handler + Validation                         |                    0.5 - 1.5 |
| Sửa query list/filter    | Repository + Filter + Resource               |                    0.5 - 1.5 |
| Thêm permission          | Middleware/Policy + Controller/Handler check |                        1 - 3 |
| Tích hợp module nội bộ   | Handler + Interface + Repository/Service     |                      1.5 - 3 |
| Tích hợp API bên ngoài   | Service + Handler + Error handling + Retry   |                        2 - 4 |
| Queue job xử lý async    | Job + DB update + Event + failed fallback    |                      1.5 - 4 |
| File upload/download     | File I/O + Storage + DB update               |                      1.5 - 4 |

> Lưu ý: Các range trong mục này chỉ dùng để tham khảo nhanh. Khi đưa vào bảng estimate cuối, bắt buộc chọn **1 point cụ thể** theo ma trận Size × Effort (§9); không để range trong cột Point (xem §14).

---

# 18. Ví Dụ Thực Tế

## Input

```text
Bóc task file SendFileMessageHandler.php cho User Story:
"Gửi file/media qua hội thoại Zalo"
```

## Output

```markdown
## [DEV] Gửi file/media qua hội thoại Zalo

> Từ scope: Bóc task file `SendFileMessageHandler.php` cho User Story "Gửi file/media qua hội thoại Zalo".
> Scope: Chỉ estimate logic trong `SendFileMessageHandler.php`, không bao gồm route/controller/request và không bao gồm implementation bên trong `SendOmnichannelFileJob`.

| #   | Task                                               | File/Dependency liên quan                                                                                                                         | Mô tả                                                                                                                            | Size | Effort   | Point   | Lý do point                                                                                                                                                         |
| --- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Kiểm tra dữ liệu và quyền gửi file                 | `SendFileMessageHandler.php`, `SendFileMessageValidationInterface` (reuse), `ChatRepositoryInterface::isUserAssignedToThread` (reuse/cần confirm) | Validate dữ liệu đầu vào, kiểm tra user là admin hoặc đã được assign vào hội thoại, báo lỗi 403 nếu không có quyền.              | S    | E        | 0.125   | Chủ yếu là gọi validation và hàm kiểm tra quyền đã có sẵn. Nếu phải viết mới hàm kiểm tra quyền thì point có thể tăng.                                              |
| 2   | Lấy thông tin hội thoại và tài khoản Zalo          | `SendFileMessageHandler.php`, `ChatRepositoryInterface` (reuse), `ZaloAccountRepositoryInterface` (reuse)                                         | Tìm hội thoại theo company, kiểm tra tồn tại, lấy Zalo account, check trạng thái kết nối, xác định hội thoại nhóm hay cá nhân.   | M    | M        | 1       | Có nhiều điều kiện nghiệp vụ cần kiểm tra trước khi gửi file. Repository được reuse nên không tính như viết mới query, nhưng vẫn cần xử lý nhiều nhánh lỗi.         |
| 3   | Upload file tạm lên S3                             | `SendFileMessageHandler.php`, `Storage::disk('s3')`, `FileManagerHelper` (reuse)                                                                  | Chuẩn hóa tên file, tạo path lưu trữ, mở stream file tạm, upload lên S3, xử lý lỗi upload, đóng stream bằng finally, lấy URL S3. | M    | H        | 1.5     | Point cao vì có xử lý file stream, upload S3, lỗi upload và đóng tài nguyên đúng cách. Nếu đã có helper upload file chuẩn để reuse thì có thể giảm còn 1.25 khi estimate thực tế. |
| 4   | Lưu tin nhắn gửi file vào database                 | `SendFileMessageHandler.php`, `ChatRepositoryInterface::createMessage` (reuse)                                                                    | Xác định loại tin nhắn media/file theo MIME type, tạo message outbound với attachment, trạng thái sending và direction out.      | S    | M        | 0.25    | Chỉ gọi repository lưu DB nhưng có mapping attachment và phân loại MIME type nên không đánh Easy hoàn toàn.                                                         |
| 5   | Đẩy job gửi file vào queue                         | `SendFileMessageHandler.php`, `SendOmnichannelFileJob` (reuse, không tính implementation job)                                                     | Dispatch job vào queue chat để worker xử lý gửi file sang Zalo sau.                                                              | S    | E        | 0.125   | Chỉ gọi job đã có sẵn và truyền tham số. Không tính phần xử lý bên trong job.                                                                                       |
| 6   | Cập nhật hoạt động hội thoại và bắn realtime event | `SendFileMessageHandler.php`, `ChatRepositoryInterface::updateThread` (reuse), `ChatMessageReceived` (reuse), `NewThreadActivity` (reuse)         | Cập nhật last_message_at và bắn event để UI cập nhật realtime.                                                                   | M    | E        | 0.5     | Có DB update và 2 event realtime, nhưng đều là gọi lại hàm/class có sẵn nên effort thấp.                                                                            |
|     |                                                    |                                                                                                                                                   |                                                                                                                                  |      | **Tổng** | **3.5** |                                                                                                                                                                     |

**Tổng: 3.5 Point = 350.000 VNĐ**

Ghi chú:

- Không tính route/controller/request vì không nằm trong snippet.
- Không tính logic gửi file sang Zalo API bên trong `SendOmnichannelFileJob`.
- Point có thể giảm thêm nếu toàn bộ upload S3 đã có helper chuẩn để tái sử dụng.
```

---

# 19. Ví Dụ Webhook Handler

## Input

```text
Bẻ việc `ChatZaloWebhookHandler.php`
Scope: Chỉ bao gồm logic điều phối và mapping dữ liệu trong handler, tái sử dụng Repository/Event/Job đã có.
```

## Output rút gọn

```markdown
## [DEV] Xử lý sự kiện webhook từ Chat Zalo

> Từ scope: Chỉ bao gồm logic điều phối và mapping dữ liệu trong `ChatZaloWebhookHandler.php`, tái sử dụng Repository/Event/Job đã có.
> Scope: Chỉ estimate logic trong `ChatZaloWebhookHandler.php`, tái sử dụng Repository/Event/Job đã có. Không tính phần nhận request/verify signature (Webhook boundary) vì handler chỉ xử lý event đã được parse sẵn.

| #   | Task                                      | File/Dependency liên quan                                                                                                | Mô tả                                                                                                                                                                              | Size | Effort   | Point     | Lý do point                                                                                                                                                                                                                                       |
| --- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | -------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Xử lý trạng thái kết nối tài khoản Zalo   | `ChatZaloWebhookHandler.php`, `ZaloAccountRepositoryInterface` (reuse), Event broadcast (reuse)                          | Xử lý các event QR/account như qr_scanned, connected, expired, disconnected, qr_error. Cập nhật trạng thái account hoặc xóa session QR, sau đó bắn realtime.                       | M    | E        | 0.5       | Có nhiều loại event nhưng logic gần giống nhau. Chủ yếu là tìm account, cập nhật trạng thái và bắn realtime. Repository/Event đã có sẵn nên không tính cao như viết mới toàn bộ.                                                                  |
| 2   | Xử lý dữ liệu tin nhắn mới từ Zalo        | `ChatZaloWebhookHandler.php`, `ChatRepositoryInterface` (reuse)                                                          | Định danh account/thread, tìm hoặc tạo thread, bóc tách payload text/file/link/sticker và chuẩn hóa dữ liệu.                                | M    | M        | 1         | Point đến từ việc payload Zalo có nhiều dạng và cần chuẩn hóa trước khi lưu. Repository được reuse nhưng logic mapping vẫn cần làm kỹ.                                                                                  |
| 3   | Lưu tin nhắn nhận được | `ChatZaloWebhookHandler.php`, `ChatRepositoryInterface` (reuse) | Lưu message inbound, khớp tin nhắn gửi đi nếu có, gọi cơ chế chống trùng đã có trong repository (không tính implementation bên trong). | M    | M        | 1         | DB Write + tìm/khớp tin nhắn + dùng cơ chế chống trùng (reuse) nên không tính như viết mới. |
| 4   | Bắn realtime và đẩy job tải media | `ChatZaloWebhookHandler.php`, `DownloadZaloMediaJob` (reuse), Event broadcast (reuse) | Bắn event UI cập nhật realtime và dispatch job tải media khi message có attachment. | M    | E        | 0.5       | Event + Queue = 2 boundary → M; cả hai chỉ gọi lại job/event có sẵn → E. |
| 5   | Xử lý thu hồi tin nhắn Zalo               | `ChatZaloWebhookHandler.php`, `ChatRepositoryInterface` (reuse)                                                          | Xử lý event message_recalled, tìm message/thread theo nhiều fallback, đảm bảo không xử lý lặp, cập nhật trạng thái thu hồi, retry nếu dữ liệu đến chưa đủ.                         | M    | H        | 1.5       | Logic khó hơn CRUD vì webhook có thể thiếu company/thread/message. Cần fallback, idempotent và retry nên effort Hard. Nếu phần này đã có sẵn và chỉ chỉnh nhẹ thì có thể giảm còn 1.0.                                                            |
| 6   | Đồng bộ tag hội thoại                     | `ChatZaloWebhookHandler.php`, `ChatRepositoryInterface` (reuse)                                                          | Xử lý event tag_synced, tìm thread và cập nhật tags JSON.                                                                                                                          | S    | E        | 0.125     | Logic đơn giản, chủ yếu gọi repository có sẵn để cập nhật tag.                                                                                                                                                                                    |
|     |                                           |                                                                                                                          |                                                                                                                                                                                    |      | **Tổng** | **4.625** |                                                                                                                                                                                                                                                   |

**Tổng: 4.625 Point = 462.500 VNĐ**
```
