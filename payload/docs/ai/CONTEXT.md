# CONTEXT — Ngôn ngữ domain HRM API

## Thuật ngữ
### Company
Đơn vị thuê bao sử dụng hệ thống. Trong codebase, dữ liệu đa phần định danh bằng `company_id`.
_Tránh gọi:_ Tenant (trừ vài trường hợp kế thừa cũ)
_Code:_ Các command/query thường yêu cầu `companyId`.

### Staff
Nhân viên thuộc một Company, người sẽ thực thi các tác vụ hoặc chat với khách.
_Tránh gọi:_ User (dễ gây nhầm lẫn với khách hàng hoặc tài khoản chung)
_Code:_ `source/src/Core/Components/OmnichannelChat/ListZaloAccountStaff/`

### Zalo OA Account (hoặc Zalo Account)
Tài khoản Zalo Official Account hoặc tài khoản cá nhân đã kết nối vào hệ thống.
_Tránh gọi:_ Zalo profile
_Code:_ `ZaloAccountRepositoryInterface`, `ZaloConnectionStatusEnum`

### Chat Thread (Omnichannel conversation)
Cuộc hội thoại đa kênh, có thể là cuộc trò chuyện 1-1 hoặc Zalo group.
_Tránh gọi:_ Chat room, Chat channel
_Code:_ `ZaloThreadTypeEnum`, `ListChatThreads`

### Chat Message
Tin nhắn cụ thể bên trong một Chat Thread.
_Tránh gọi:_ Chat log, chat text
_Code:_ `MessageDirectionEnum`, `MessageTypeEnum`, `ListChatMessages`

### Forward Target
Đích đến để chuyển tiếp (forward) tin nhắn.
_Tránh gọi:_ Forward destination, forward recipient
_Code:_ `ListForwardTargets`

### Message Reader
Người dùng đã đọc một tin nhắn.
_Tránh gọi:_ Seen user
_Code:_ `ListMessageReaders`

### Webhook Event
Sự kiện được đẩy (push) từ nền tảng bên ngoài (VD: Zalo) về hệ thống, ví dụ: NewMessage, AccountLifecycle, Friendship...
_Tránh gọi:_ Callback, API trigger
_Code:_ `source/src/Core/Components/OmnichannelChat/HandleChatZaloWebhook/Events/`

### Command và Query
Tuân theo CQRS pattern. `Command` biểu diễn một thao tác ghi (đổi state), `Query` biểu diễn thao tác đọc.
_Tránh gọi:_ Action, Request, Payload

### Handler
Lớp thực thi logic chính cho một `Command` hoặc `Query`. Mỗi Command/Query chỉ có một Handler.
_Code:_ `<Feature>Handler.php`

### ValidationInterface
Interface quy định contract để validate Command/Query trước khi Handler xử lý.
_Code:_ `<Feature>ValidationInterface.php`

### BusinessException
Exception được ném ra khi vi phạm các business rule của module.
_Tránh gọi:_ LogicException, DomainException, ErrorException

## Quan hệ
- Một `Company` có nhiều `Staff`.
- Một `Company` có thể kết nối nhiều `Zalo OA Account`.
- Một `Chat Thread` thuộc về một hệ thống, chứa nhiều `Chat Message`.
- Một `Command` / `Query` đi đôi với đúng 1 `Handler` và 1 `ValidationInterface`.

## Nhập nhằng đã chốt
- **Tenant vs Company:** Trong hệ thống hiện tại, thuật ngữ chuẩn ưu tiên dùng là `Company` (`company_id`). "Tenant" chỉ còn rải rác ở vài hàm infrastructure cũ.
- **User vs Staff:** Trong hệ thống chat đa kênh và phần lớn module nội bộ, nhân viên vận hành được gọi là "Staff". Từ "User" chỉ dùng cho khái niệm tài khoản đăng nhập mức cơ sở hạ tầng.
