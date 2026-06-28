# Tìm kiếm liên hệ Zalo theo số điện thoại

`POST /api/v1/omnichannel/zalo/contacts/search`
**Auth:** Bearer token

Tìm một người dùng Zalo theo số điện thoại từ một tài khoản Zalo đã kết nối; trả về thông tin liên hệ và trạng thái quan hệ bạn bè.

## Request

Request body:

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| accountId | integer | ✅ | ID tài khoản Zalo (đã kết nối) dùng để tìm kiếm. Phải >= 1. |
| phone | string | ✅ | Số điện thoại cần tìm. Định dạng VN: `0xxxxxxxxx`, `84xxxxxxxxx` hoặc `+84xxxxxxxxx` (9 số sau đầu mã). |

```json
{
  "accountId": 12,
  "phone": "0901234567"
}
```

## Response 200

```json
{
  "data": {
    "zaloUserId": "5123456789012345678",
    "displayName": "Nguyễn Văn A",
    "avatarUrl": "https://s120.../avatar.jpg",
    "phoneNumber": "0901234567",
    "friendshipStatus": "NONE"
  },
  "status": "success",
  "code": 200,
  "message": "Tìm kiếm liên hệ thành công"
}
```

`friendshipStatus`: NONE | REQUEST_SENT | REQUEST_RECEIVED | REJECTED | FRIEND

## Lỗi

| HTTP | message | Khi nào |
|---|---|---|
| 422 | Vui lòng nhập số điện thoại. | Thiếu `phone`. |
| 422 | Số điện thoại không hợp lệ. | `phone` sai định dạng (regex). |
| 422 | (lỗi đầu tiên của validator) | `accountId` thiếu hoặc < 1. |
| 404 | Không tìm thấy tài khoản Zalo. | Không có tài khoản Zalo khớp `accountId` trong công ty. |
| 422 | Tài khoản Zalo chưa kết nối. | Tài khoản Zalo tồn tại nhưng `connection_status` khác `CONNECTED`. |
| 404 | Không tìm thấy người dùng với số điện thoại này. | ChatZalo không trả về `uid`/`userId` (không tìm thấy người dùng), hoặc API trả mã `PHONE_NOT_FOUND`. |
| 503 | Không thể kết nối tới ChatZalo. | Lỗi kết nối tới dịch vụ ChatZalo. |
