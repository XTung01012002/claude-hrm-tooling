# API Docs cho Frontend

Tài liệu **hợp đồng gọi API** dành cho FE: endpoint, tham số, payload mẫu, response mẫu, bảng lỗi. Ngắn gọn, đúng trọng tâm.

> Khác với thư mục `docs/` (tài liệu **logic nội bộ** cho BE: sơ đồ luồng, classes liên quan...). FE chỉ cần `api-docs/`.
>
> Quy ước: 1 file / endpoint, đặt tại `api-docs/<Module>/<Endpoint>.md`. Sinh/cập nhật bằng `/api-docs` (xem `docs/ai/prompts/generate-api-docs.md`). Mọi field/response/lỗi lấy từ code thật — không bịa.

## Envelope chung (toàn cục, ở `source/bootstrap/app.php` + `ApiBaseController`)
- Thành công (detail/action): `{ "data": {...}, "status": "success", "code": 200, "message": "..." }`
- Thành công (list): `{ "data": [...], "links": {...}, "meta": {...}, "status": "success", "code": 200, "message": "..." }`
- Lỗi: `{ "status": "error", "code": <http|string>, "message": "...", "errors"?: { "<field>": "<message>" } }`
- Auth: hầu hết endpoint dùng Bearer token (JWT). `companyId` backend tự lấy từ token — FE không truyền.

## OmnichannelChat — Zalo
| API | Method | Endpoint |
|---|---|---|
| [Lấy trạng thái kết bạn](OmnichannelChat/GetFriendStatus.md) | GET | `/api/v1/omnichannel/zalo/friends/status` |
| [Gửi lời mời kết bạn](OmnichannelChat/SendFriendRequest.md) | POST | `/api/v1/omnichannel/zalo/friends/request` |
| [Từ chối lời mời kết bạn](OmnichannelChat/RejectFriendRequest.md) | POST | `/api/v1/omnichannel/zalo/friends/requests/reject` |
| [Danh sách lời mời đã gửi](OmnichannelChat/ListSentFriendRequests.md) | GET | `/api/v1/omnichannel/zalo/friends/requests/sent` |
| [Tìm contact theo số điện thoại](OmnichannelChat/SearchZaloContact.md) | POST | `/api/v1/omnichannel/zalo/contacts/search` |
| [Danh sách contact](OmnichannelChat/ListZaloContacts.md) | GET | `/api/v1/omnichannel/zalo/contacts` |
| [WebSocket: trạng thái kết bạn realtime](OmnichannelChat/ZaloFriendshipEvents.md) | WS | `.ZaloFriendshipChanged` |
