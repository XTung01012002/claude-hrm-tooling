# Ví Dụ Webhook Handler

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
