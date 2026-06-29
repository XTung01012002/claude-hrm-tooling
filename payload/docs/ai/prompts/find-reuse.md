# Find Reuse Candidates

> Quy ước cốt lõi: Reuse-first + DRY (PROJECT-CONVENTIONS §1 & §2).

Kỹ năng này định hướng quá trình tìm kiếm các component/interface/trait dùng chung trước khi bạn định viết code mới, để đảm bảo DRY (Don't Repeat Yourself).

**Quy trình tìm kiếm:**
1. Khi có ý định viết một Controller, Handler, hoặc Repository function/logic mới, **ĐỪNG viết ngay**.
2. Phân tích các danh từ chính, logic nghiệp vụ để tìm kiếm keyword.
3. Dùng công cụ tìm kiếm (Grep/Ripgrep) để tìm các function trùng tên hoặc logic liên quan trong:
   - `source/src/Core/Components/<Module>/Shared/` (Chứa các interface/DTO dùng chung).
   - `source/src/Infrastructure/<Module>/Repositories/` (Các repo hiện có).
   - `source/src/Infrastructure/Shared/Helper.php` hoặc các class `*Trait`.
4. Nếu tìm thấy logic/interface tương đương, hãy tái sử dụng (import/inject) thay vì copy-paste hoặc bịa ra code mới.
5. In ra các ứng viên có khả năng tái sử dụng (hoặc báo là không tìm thấy) để người dùng nắm được kết quả.
