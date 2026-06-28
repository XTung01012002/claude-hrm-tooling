# Danh sách lời mời kết bạn đã gửi

`GET /api/v1/omnichannel/zalo/friends/requests/sent`
**Auth:** Bearer token

Lấy danh sách (phân trang) các lời mời kết bạn đã gửi đi (`friendshipStatus = REQUEST_SENT`) của một tài khoản Zalo. Backend đồng bộ real-time từ Zalo trước rồi phân trang trên DB.

## Request
Query params:

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `accountId` | integer (>= 1) | ✅ | ID tài khoản Zalo của công ty |
| `search` | string (max 255) | ❌ | Tìm theo tên hiển thị / số điện thoại / zaloUserId |
| `sortBy` | string | ❌ | `requestedAt` \| `displayName` \| `createdAt` (mặc định `requestedAt`) |
| `sortOrder` | string | ❌ | `asc` \| `desc` (mặc định `desc`) |
| `limit` (hoặc `per_page`) | integer (1–100) | ❌ | Số bản ghi mỗi trang (mặc định 20) |
| `page` | integer (>= 1) | ❌ | Trang hiện tại (mặc định 1) |

```
GET /api/v1/omnichannel/zalo/friends/requests/sent?accountId=12&search=an&sortBy=requestedAt&sortOrder=desc&limit=20&page=1
```

## Response 200
```json
{
  "data": [
    {
      "id": 101,
      "zaloUserId": "1234567890",
      "displayName": "Nguyễn Văn An",
      "avatarUrl": "https://s120-ava-talk.zadn.vn/abc.jpg",
      "phoneNumber": "0901234567",
      "friendshipStatus": "REQUEST_SENT",
      "requestMessage": "Kết bạn với mình nhé!",
      "requestedAt": "2026-06-20T08:30:00.000000Z",
      "friendedAt": null,
      "lastSyncedAt": "2026-06-28T07:15:00.000000Z"
    }
  ],
  "links": {
    "first": "http://.../api/v1/omnichannel/zalo/friends/requests/sent?page=1",
    "last": "http://.../api/v1/omnichannel/zalo/friends/requests/sent?page=2",
    "prev": null,
    "next": "http://.../api/v1/omnichannel/zalo/friends/requests/sent?page=2"
  },
  "meta": {
    "currentPage": 1,
    "from": 1,
    "lastPage": 2,
    "path": "http://.../api/v1/omnichannel/zalo/friends/requests/sent",
    "perPage": 20,
    "to": 20,
    "total": 35
  },
  "status": "success",
  "code": 200,
  "message": "Success"
}
```

- Mọi item đều có `friendshipStatus = "REQUEST_SENT"` (danh sách đã lọc sẵn).
- `requestedAt`, `friendedAt`, `lastSyncedAt`: chuỗi ISO 8601 hoặc `null`.

## Lỗi
| HTTP | message | Khi nào |
|---|---|---|
| 422 | (lỗi validate đầu tiên) | `accountId` thiếu/< 1, `search` > 255, `sortBy`/`sortOrder` ngoài enum, `limit` ngoài 1–100, `page` < 1 |
| 404 | Không tìm thấy tài khoản Zalo. | `accountId` không thuộc công ty / không tồn tại |
| 422 | Tài khoản Zalo chưa kết nối. | Tài khoản Zalo có nhưng `connection_status` != CONNECTED |
| 502 | Dữ liệu danh sách lời mời đã gửi từ Zalo không hợp lệ. | Phản hồi từ ChatZalo thiếu/không hợp lệ trường `items` |
| 401 | (Unauthorized) | Thiếu/không hợp lệ Bearer token |

> Ngoài ra có thể gặp lỗi upstream từ ChatZalo (timeout/kết nối) theo envelope lỗi chung `{ "status": "error", "code", "message", "errors"? }`.
