# Find Reuse Candidates

> Quy ước cốt lõi: Reuse-first + DRY (`docs/ai/PROJECT-CONVENTIONS.md` §1 & §2), đồng thời tuân thủ §0: đọc code thật, không bịa.

## Mục tiêu và phạm vi

Tìm component/interface/method/trait có thể tái sử dụng **trước khi** viết Controller, Handler, Repository hoặc logic mới.

Đầu vào phải có module và mô tả ngắn về class/method/behavior dự định viết. Nếu người dùng chưa cung cấp đủ phạm vi, hãy hỏi lại; không tự suy ra từ `git diff`.

Đây là bước **chỉ đọc và báo cáo**. Không tạo/sửa file, không tự refactor và không triển khai ứng viên ngay trong bước này.

## 1. Tạo bộ từ khóa tìm kiếm

Phân tích tên dự kiến và behavior nghiệp vụ thành nhiều nhóm từ khóa, không chỉ tìm đúng một tên class:

- **Danh từ nghiệp vụ:** entity, trạng thái, tài nguyên và module liên quan; thử số ít/số nhiều và tên gần nghĩa. Ví dụ `SyncZaloFriendStatusHandler` → `FriendStatus`, `FriendshipStatus`, `ZaloContact`, `friend`, `friends`.
- **Động từ/hành vi:** thử các động từ có thể biểu diễn cùng intent như `sync`, `update`, `refresh`, `save`, `persist`, `resolve`, `preserve`.
- **Dấu hiệu behavior:** tên Model/table, enum, message lỗi, method dependency, field input/output hoặc đoạn điều kiện đặc trưng nếu đã biết.
- **Biến thể cách viết:** PascalCase, camelCase, snake_case và biểu thức ghép như `Sync.*Status`, `update.*friend`.

Phải thử tối thiểu 3 nhóm từ khóa: tên/symbol gần chính xác, biến thể đồng nghĩa và dấu hiệu behavior. Dùng `rg`/`rg -i` để tìm symbol lẫn nội dung; không kết luận chỉ từ một lần grep không có kết quả.

## 2. Tìm theo đúng thứ tự kiến trúc

Ưu tiên trong cùng module trước:

1. **Core contract dùng chung:** `source/src/Core/Components/<Module>/Shared/` — interface, DTO, enum, util đã có.
2. **Feature trong Core cùng module:** `source/src/Core/Components/<Module>/**/*Handler.php`, `*Command.php`, `*Query.php`, `*ValidationInterface.php` — tìm cả logic private tương tự và duplicate giữa các Handler.
3. **Infrastructure cùng module:**
   - `source/src/Infrastructure/<Module>/Repositories/` — implementation repository hiện có.
   - `source/src/Infrastructure/<Module>/Validations/` — validation implementation/rule tương tự.
   - Mapper, Provider, `*Trait.php` và helper thuộc module.
4. **Presentation cùng module:** `source/src/Presentation/API/Controllers/<Module>/` nếu đang dự định thêm/sửa Controller hoặc endpoint tương tự.

Sau đó mới mở rộng phạm vi:

5. **Shared toàn hệ thống:** `source/src/Core/Components/Shared/`, `source/src/Infrastructure/Shared/Helper.php` và các trait/helper dùng chung.
6. **Module khác:** chỉ tìm để nhận diện logic thực sự dùng chung hoặc tiền lệ kiến trúc; không mặc định import trực tiếp Core/Infrastructure của một bounded context nghiệp vụ khác.

Khi tìm repository/validation qua interface, phải tìm cả hai phía: contract ở Core, implementation và binding trong ServiceProvider ở Infrastructure. Có thể đọc caller và test liên quan để hiểu behavior thực tế.

## 3. Verify từng ứng viên bằng code thật

Grep chỉ tạo danh sách ban đầu. Trước khi đề xuất một ứng viên, phải đọc definition và code liên quan để xác nhận:

- Method signature, kiểu input/output và nullable/default value có tương thích không.
- Behavior, điều kiện nghiệp vụ, exception/message và side effect có cùng intent không.
- Tenant/account scope, transaction/locking, cache, event/job và external API có phù hợp không.
- Interface đã có implementation/binding thật hay chỉ là contract chưa dùng.
- Caller/test hiện tại có ràng buộc behavior khiến việc mở rộng làm breaking change không.

Không đề xuất chỉ vì trùng tên. Ngược lại, nếu tên khác nhưng behavior tương đương thì vẫn phải ghi nhận.

## 4. Phân loại kết quả

- **Khớp hoàn toàn — dùng thẳng:** contract và behavior đáp ứng yêu cầu mà không cần đổi public API.
- **Khớp một phần — cân nhắc mở rộng hoặc tách dùng chung:** nêu chính xác phần dùng lại được, phần còn thiếu và ảnh hưởng tới caller hiện có. Không tự thêm tham số hay đổi behavior của method cũ.
- **Không phù hợp — cần viết mới:** các ứng viên gần nhất khác intent/contract, hoặc reuse sẽ tạo coupling sai tầng/sai bounded context. Giải thích ngắn gọn vì sao viết mới hợp lý.

Nếu logic tương tự xuất hiện ở nhiều module và thực sự trung lập về nghiệp vụ, đề xuất trích abstraction vào vị trí Shared phù hợp. Không import chéo trực tiếp giữa hai module nghiệp vụ chỉ để tránh vài dòng lặp, và không tạo abstraction chung khi mới có một nơi sử dụng.

## 5. Tiêu chí dừng tìm kiếm

- Hoàn thành ít nhất 3 nhóm từ khóa và toàn bộ phạm vi bắt buộc trong cùng module + Shared.
- Từ ứng viên tìm được, có thể mở rộng từ khóa tối đa 2 lượt dựa trên symbol/caller mới phát hiện.
- Dừng sớm khi một lượt tìm đầy đủ không tạo thêm ứng viên liên quan; không tiếp tục quét mù toàn repository.
- Nếu thư mục, binding hoặc code cần verify không tồn tại/không truy cập được, ghi rõ giới hạn đó thay vì kết luận chắc chắn.

## 6. Định dạng output

```markdown
## Phạm vi tìm kiếm
- Ý định: <class/method/behavior dự định viết>
- Module: <Module>
- Từ khóa đã thử: <các nhóm từ khóa>
- Vị trí đã tìm: <các thư mục/file chính>

## Ứng viên
| Mức khớp | Ứng viên | Bằng chứng | Phần còn thiếu/rủi ro | Đề xuất |
|---|---|---|---|---|
| Hoàn toàn/Một phần/Không phù hợp | `FQCN::method()` | `file.php:line` + signature/behavior đã verify | ... | Dùng thẳng/Mở rộng/Tách shared/Viết mới |

## Kết luận đề xuất
<Nêu hướng phù hợp nhất và lý do. Nếu không có ứng viên, xác nhận rõ cần viết mới dựa trên phạm vi đã tìm.>

## Cần người dùng xác nhận
<Một câu hỏi chọn dùng thẳng, mở rộng/tách shared hay viết mới.>
```

Nếu không tìm thấy ứng viên, vẫn phải liệt kê từ khóa và phạm vi đã tìm; không chỉ trả lời `Không tìm thấy`.

Sau khi in kết quả, **dừng và chờ người dùng xác nhận hướng xử lý**. Không reuse, mở rộng, refactor hoặc viết code mới trước khi được xác nhận.
