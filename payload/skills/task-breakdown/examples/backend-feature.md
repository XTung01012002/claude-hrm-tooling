# Ví Dụ Bóc Task Backend Feature

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
