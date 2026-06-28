# WebSocket — Zalo Friendship realtime (`ZaloFriendshipChanged`)

Realtime cập nhật trạng thái kết bạn Zalo cho FE (nhận lời mời / chấp nhận / từ chối / hủy kết bạn).

- **Broadcast as:** `ZaloFriendshipChanged` → Laravel Echo listen: `.ZaloFriendshipChanged`
- **Channel:** private `omnichannel.user.{uid}` (phát tới từng user được gán vào tài khoản Zalo)
- **Wrapper:** mọi event đều bọc dạng `{ "event": <tên>, "payload": {...} }`

```js
Echo.private(`omnichannel.user.${uid}`)
  .listen('.ZaloFriendshipChanged', (e) => {
    // e.event: 'friend_request_received' | 'friend_accepted' | 'friend_request_rejected' | 'friend_removed'
    // e.payload.friendshipStatus: cập nhật UI theo field này
  })
```

`friendshipStatus`: `NONE` | `REQUEST_SENT` | `REQUEST_RECEIVED` | `REJECTED` | `FRIEND`. FE nên render theo `friendshipStatus` trong payload.

---

## 1. `friend_request_received` — khách gửi lời mời đến tài khoản Zalo
```json
{
  "event": "friend_request_received",
  "payload": {
    "accountId": 597,
    "zaloAccountId": "cmq577dfz00jy12kri8r1n89d",
    "zaloAccountName": "Tài khoản A",
    "fromUid": "1089773590197384263",
    "fromName": "Người dùng B",
    "message": "Xin chào",
    "receivedAt": "2026-06-28T08:00:00.000000Z",
    "friendshipStatus": "REQUEST_RECEIVED"
  }
}
```
- `message` có thể `null`. `receivedAt` định dạng ISO 8601.

## 2. `friend_accepted` — lời mời được chấp nhận (đã là bạn)
```json
{
  "event": "friend_accepted",
  "payload": {
    "accountId": 597,
    "zaloAccountId": "cmq577dfz00jy12kri8r1n89d",
    "userId": "1089773590197384263",
    "acceptedAt": "2026-06-28T08:00:00.000000Z",
    "friendshipStatus": "FRIEND"
  }
}
```

## 3. `friend_request_rejected` — lời mời bị từ chối
```json
{
  "event": "friend_request_rejected",
  "payload": {
    "accountId": 597,
    "zaloAccountId": "cmq577dfz00jy12kri8r1n89d",
    "userId": "1089773590197384263",
    "rejectedBy": null,
    "rejectedAt": "2026-06-28T08:00:00.000000Z",
    "friendshipStatus": "REJECTED"
  }
}
```
- `rejectedBy`: giá trị truyền thẳng từ webhook Zalo, **có thể `null`** (backend không chuẩn hóa). `rejectedAt` ISO 8601.

## 4. `friend_removed` — bị hủy kết bạn
```json
{
  "event": "friend_removed",
  "payload": {
    "accountId": 597,
    "zaloAccountId": "cmq577dfz00jy12kri8r1n89d",
    "userId": "1089773590197384263",
    "removedAt": "2026-06-28T08:00:00.000000Z",
    "friendshipStatus": "NONE"
  }
}
```

---

## Mapping nhanh cho FE
| `event` | `payload.friendshipStatus` | FE làm gì |
|---|---|---|
| `friend_request_received` | `REQUEST_RECEIVED` | Hiện lời mời đến, nút Chấp nhận/Từ chối |
| `friend_accepted` | `FRIEND` | Chuyển thành bạn bè |
| `friend_request_rejected` | `REJECTED` | Chuyển thành bị từ chối |
| `friend_removed` | `NONE` | Chuyển về chưa kết bạn |
