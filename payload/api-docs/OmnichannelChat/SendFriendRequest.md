# Gửi lời mời kết bạn Zalo

`POST /api/v1/omnichannel/zalo/friends/request`
**Auth:** Bearer token

Gửi lời mời kết bạn từ một tài khoản Zalo của công ty tới một người dùng Zalo.

## Request

Request body:

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| accountId | integer (>=1) | ✅ | ID tài khoản Zalo nội bộ dùng để gửi lời mời |
| userId | string (max 64) | ✅ | ID người dùng Zalo nhận lời mời |
| message | string (max 150) | ❌ | Nội dung lời nhắn kèm lời mời |

```json
{
  "accountId": 12,
  "userId": "3456789012345678901",
  "message": "Xin chào, kết bạn với mình nhé!"
}
```

## Response 200

```json
{
  "data": {
    "message": "Đã gửi yêu cầu kết bạn.",
    "friendshipStatus": "REQUEST_SENT"
  },
  "status": "success",
  "code": 200,
  "message": "Gửi lời mời kết bạn thành công"
}
```

`friendshipStatus`: NONE | REQUEST_SENT | REQUEST_RECEIVED | REJECTED | FRIEND (sau khi gửi thành công luôn trả `REQUEST_SENT`).

## Lỗi

| HTTP | message | Khi nào |
|---|---|---|
| 422 | (lỗi đầu tiên) | Validation fail. `errors`: `{ "userId": "Vui lòng chọn người dùng.", "message": "Nội dung lời nhắn không được vượt quá 150 ký tự." }` |
| 404 | Không tìm thấy tài khoản Zalo. | `accountId` không thuộc công ty hoặc không tồn tại |
| 422 | Tài khoản Zalo chưa kết nối. | Tài khoản Zalo chưa ở trạng thái CONNECTED |
| 404 | Không tìm thấy người dùng Zalo | Zalo trả `USER_NOT_FOUND` (`errors.code` = USER_NOT_FOUND) |
| 422 | Hai bạn đã là bạn bè | Zalo trả `ALREADY_FRIENDS` |
| 422 | Yêu cầu kết bạn đã được gửi trước đó | Zalo trả `ALREADY_REQUESTED` |
| 429 | Đã vượt quá giới hạn gửi tin cho người lạ | Zalo trả `STRANGER_LIMIT` |
| 503 | Không thể kết nối tới ChatZalo. | Lỗi kết nối tới dịch vụ ChatZalo (`errors.code`: CHATZALO_UNREACHABLE / CHATZALO_SEND_TIMEOUT / CHATZALO_CONNECTION_ERROR) |
| 401 | (Unauthorized) | Thiếu/không hợp lệ Bearer token |
