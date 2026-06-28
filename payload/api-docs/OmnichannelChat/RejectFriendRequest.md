# Từ chối lời mời kết bạn Zalo

`POST /api/v1/omnichannel/zalo/friends/requests/reject`
**Auth:** Bearer token

Từ chối lời mời kết bạn Zalo từ một người dùng, qua tài khoản Zalo đã kết nối của công ty.

## Request

Request body

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| accountId | integer (>= 1) | ✅ | ID tài khoản Zalo (bản ghi nội bộ) dùng để từ chối lời mời |
| userId | string (max 64) | ✅ | ID người dùng Zalo bị từ chối kết bạn |

```json
{
  "accountId": 12,
  "userId": "8123456789012345"
}
```

## Response 200

```json
{
  "data": {
    "message": "Đã từ chối yêu cầu kết bạn.",
    "friendshipStatus": "REJECTED"
  },
  "status": "success",
  "code": 200,
  "message": "Từ chối kết bạn thành công"
}
```

`friendshipStatus`: NONE | REQUEST_SENT | REQUEST_RECEIVED | REJECTED | FRIEND (endpoint này luôn trả `REJECTED`)

## Lỗi

| HTTP | message | Khi nào |
|---|---|---|
| 422 | `<lỗi đầu tiên>` (vd: The account id field is required.) | Validation thất bại (`accountId`/`userId` thiếu hoặc sai kiểu/độ dài); `errors` = `{ field: message }` |
| 404 | Không tìm thấy tài khoản Zalo. | `accountId` không tồn tại / không thuộc công ty |
| 422 | Tài khoản Zalo chưa kết nối. | Tài khoản Zalo có nhưng `connection_status` không phải CONNECTED |
| 404 | Không tìm thấy người dùng Zalo | Dịch vụ Zalo trả `USER_NOT_FOUND` (`errors.code = USER_NOT_FOUND`) |
| 422 | Hai bạn đã là bạn bè | Dịch vụ Zalo trả `ALREADY_FRIENDS` |
| 422 | Tài khoản Zalo đã ngắt kết nối | Dịch vụ Zalo trả `ACCOUNT_DISCONNECTED` |
| 503 | Không thể kết nối tới ChatZalo. | Không gọi được dịch vụ ChatZalo (timeout/unreachable) |
| 401 | Unauthorized | Thiếu hoặc sai Bearer token |
