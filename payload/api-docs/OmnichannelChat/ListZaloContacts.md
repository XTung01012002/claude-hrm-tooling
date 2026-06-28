# Danh sách liên hệ Zalo

`GET /api/v1/omnichannel/zalo/contacts`
**Auth:** Bearer token

Lấy danh sách (phân trang) liên hệ Zalo của một tài khoản Zalo trong công ty, hỗ trợ tìm kiếm, lọc theo trạng thái kết bạn và sắp xếp.

## Request

Query params:

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `accountId` | integer (>= 1) | ✅ | ID tài khoản Zalo (omnichannel account) cần lấy liên hệ |
| `search` | string (max 255) | ❌ | Từ khóa tìm theo tên hiển thị, số điện thoại hoặc zaloUserId |
| `status` | string (enum) | ❌ | Lọc theo trạng thái kết bạn: `NONE` \| `REQUEST_SENT` \| `REQUEST_RECEIVED` \| `REJECTED` \| `FRIEND` |
| `sortBy` | string | ❌ | Cột sắp xếp: `display_name` \| `created_at` \| `friended_at` \| `last_synced_at` (mặc định `display_name`) |
| `sortOrder` | string | ❌ | `asc` \| `desc` (mặc định `asc`) |
| `limit` (hoặc `per_page`) | integer (1–100) | ❌ | Số bản ghi mỗi trang (mặc định 20) |
| `page` | integer (>= 1) | ❌ | Trang hiện tại (mặc định 1) |

Ví dụ:

```
GET /api/v1/omnichannel/zalo/contacts?accountId=12&status=FRIEND&search=an&sortBy=display_name&sortOrder=asc&limit=20&page=1
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
      "friendshipStatus": "FRIEND",
      "requestMessage": null,
      "requestedAt": "2026-06-01T08:30:00.000000Z",
      "friendedAt": "2026-06-02T09:00:00.000000Z",
      "lastSyncedAt": "2026-06-28T07:15:00.000000Z"
    }
  ],
  "links": {
    "first": "http://.../api/v1/omnichannel/zalo/contacts?page=1",
    "last": "http://.../api/v1/omnichannel/zalo/contacts?page=5",
    "prev": null,
    "next": "http://.../api/v1/omnichannel/zalo/contacts?page=2"
  },
  "meta": {
    "currentPage": 1,
    "from": 1,
    "lastPage": 5,
    "path": "http://.../api/v1/omnichannel/zalo/contacts",
    "perPage": 20,
    "to": 20,
    "total": 95,
    "contactsSyncedAt": "2026-06-28T07:00:00.000000Z"
  },
  "status": "success",
  "code": 200,
  "message": "Success"
}
```

- `friendshipStatus`: `NONE` | `REQUEST_SENT` | `REQUEST_RECEIVED` | `REJECTED` | `FRIEND`
- `requestedAt`, `friendedAt`, `lastSyncedAt`, `meta.contactsSyncedAt`: chuỗi ISO 8601 hoặc `null`.

## Lỗi

| HTTP | message | Khi nào |
|---|---|---|
| 404 | Không tìm thấy tài khoản Zalo. | `accountId` không thuộc công ty hoặc không tồn tại |
| 422 | (lỗi validate đầu tiên) | Sai/thiếu tham số: `accountId` thiếu hoặc < 1, `search` > 255 ký tự, `status` không thuộc enum, `sortBy`/`sortOrder` không hợp lệ, `limit` ngoài 1–100, `page` < 1 |
| 401 | (chưa đăng nhập) | Thiếu/không hợp lệ Bearer token |
