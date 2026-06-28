# Lấy trạng thái kết bạn Zalo

`GET /api/v1/omnichannel/zalo/friends/status`
**Auth:** Bearer token

Kiểm tra trạng thái kết bạn giữa tài khoản Zalo đã kết nối và một người dùng Zalo (theo `userId`).

## Request
Query params

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `accountId` | integer (>= 1) | ✅ | ID tài khoản Zalo (đã kết nối) của công ty |
| `userId` | string (max 64) | ✅ | Zalo userId của người cần kiểm tra trạng thái kết bạn |

```
GET /api/v1/omnichannel/zalo/friends/status?accountId=12&userId=2900000000000000000
```

## Response 200
```json
{
  "data": {
    "isFriend": false,
    "isRequesting": false,
    "isRequested": true,
    "friendshipStatus": "REQUEST_SENT"
  },
  "status": "success",
  "code": 200,
  "message": "Lấy trạng thái kết bạn thành công"
}
```

`friendshipStatus`: NONE | REQUEST_SENT | REQUEST_RECEIVED | REJECTED | FRIEND

- `isFriend` = true → `FRIEND`; `isRequesting` = true → `REQUEST_RECEIVED`; `isRequested` = true → `REQUEST_SENT`; còn lại → `NONE`.
- Nếu Zalo trả về `NONE` nhưng đã có vết từ chối trước đó (local lưu `REJECTED`) thì `friendshipStatus` giữ `REJECTED`.

## Lỗi
| HTTP | message | Khi nào |
|---|---|---|
| 422 | (lỗi đầu tiên của validation) | `accountId` thiếu/không phải integer/< 1, hoặc `userId` thiếu/quá 64 ký tự |
| 404 | Không tìm thấy tài khoản Zalo. | `accountId` không thuộc công ty hoặc không tồn tại |
| 422 | Tài khoản Zalo chưa kết nối. | Tài khoản Zalo có nhưng `connection_status` != CONNECTED |
| 404 | Không tìm thấy người dùng Zalo | ChatZalo trả `errorCode = USER_NOT_FOUND` |
| 503 | Không thể kết nối tới ChatZalo. | Không gọi được hệ thống ChatZalo (timeout / lỗi kết nối) |

> Lỗi validation 422: `{ "status": "error", "code": 422, "message": "<lỗi đầu>", "errors": { "<field>": "<message>" } }`.
> Lỗi nghiệp vụ: `{ "status": "error", "code": <HTTP>, "message": "...", "errors"?: { "code": "<mã lỗi Zalo>" } }`.
