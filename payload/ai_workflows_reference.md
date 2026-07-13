# 📚 Hướng dẫn sử dụng Workflows / Skills / Slash Commands của AI

Dưới đây là bảng tổng hợp tất cả các Workflows / Skills / Slash Commands hiện có trong dự án, được phân nhóm theo mục đích sử dụng để bạn dễ dàng tra cứu:

> Cập nhật theo tooling `1.7.1`: nhóm review dùng chung verdict `PASS` / `PASS_WITH_CONCERNS` / `REQUEST_CHANGES` / `BLOCKED_INSUFFICIENT_CONTEXT`; `/verify` chuẩn hóa file scope/base range/staged/untracked và sẽ `BLOCKED_INSUFFICIENT_CONTEXT` nếu chỉ có attachment mà không có diff/base; `/implement` luôn chụp baseline workspace và audit diff cuối trước khi báo xong.

### 1. 🏗️ Nhóm Triển khai & Tạo mới (Implementation & Scaffold)

| Lệnh / Skill | Ý nghĩa cơ bản | Khi nào nên dùng? (Trường hợp áp dụng) |
| :--- | :--- | :--- |
| `/implement` | Triển khai yêu cầu (Code) | Khi bạn có một Yêu cầu mới (Feature/Bug fix) và muốn AI tự động **baseline workspace → phân tích → lập kế hoạch → viết code → chạy quality gate → audit diff cuối**. Lệnh này không còn ép mọi thay đổi vào khuôn 3 file; bugfix/repo/job/controller/helper sẽ đi theo pattern tương ứng. |
| `/scaffold-feature` | Tạo khung code (Skeleton) | Khi bạn bắt đầu làm 1 Core use case mới và cần AI tự động sinh sẵn các file rỗng chuẩn kiến trúc (Command/Query, Handler, Validation Interface) để bạn tự viết logic vào sau. Sau khi sinh file, AI phải kiểm tra toàn bộ PHP file vừa tạo bằng lint/format theo Makefile.ai. |
| `/scaffold-test` | Sinh Unit Test | Khi bạn đã viết xong 1 class/method và muốn AI sinh file Unit Test (PHPUnit + Mockery theo chuẩn AAA) cho class đó. |
| `/find-reuse` / `find-reuse-candidates` | Tìm code tái sử dụng | Khi bạn chuẩn bị viết một logic mới nhưng nghi ngờ rằng logic này hoặc interface này đã từng được ai đó viết rồi (ở các folder Shared, Trait, Helper). Dùng lệnh/skill này trước khi code để tuân thủ rule DRY / Reuse-first. |

### 2. 🔍 Nhóm Đánh giá & Kiểm định (Review & Verify)

| Lệnh / Skill | Ý nghĩa cơ bản | Khi nào nên dùng? (Trường hợp áp dụng) |
| :--- | :--- | :--- |
| `/review` | Review diff đang có | Khi bạn (hoặc AI) vừa viết code xong, muốn AI kiểm tra lại toàn bộ file vừa sửa xem có vi phạm convention, layering, lỗi ORM hay bẫy nào của HRM API không. Output dùng severity `BLOCKER` / `IMPORTANT` / `SUGGESTION` / `QUESTION` và verdict chung của tooling. |
| `/verify` | Kiểm định chéo (Adversarial) | Khi code đã xong xuôi và chuẩn bị tạo Pull Request. Lệnh này đóng vai trò như một "Reviewer khó tính", chỉ soi lỗi và rủi ro chứ không sửa. Nếu truyền file cụ thể, AI phải lấy diff theo base/range cho đúng file đó; nếu không có scope rõ thì kiểm cả staged, unstaged và untracked. |
| `/refactor` | Tái cấu trúc code | Khi bạn thấy một đoạn code cũ quá lộn xộn hoặc vi phạm chuẩn, muốn AI làm sạch mà **vẫn giữ nguyên logic/behavior** (surgical refactor). Finding cũng dùng severity chung `BLOCKER` / `IMPORTANT` / `SUGGESTION` / `QUESTION`. |
| `/diff-review` | Review diff + sinh PR Summary & Commit | Khi bạn muốn review tóm tắt các thay đổi hiện tại và tự động sinh ra tên Branch, câu lệnh Commit, cùng với tóm tắt để điền vào mô tả Pull Request (PR). Chỉ sinh branch/commit khi verdict là `PASS` hoặc `PASS_WITH_CONCERNS` và không có `Merge blocking: Yes`. |
| `/review-vs-plan`| Đối chiếu code với kế hoạch | Khi dùng `/implement` xong, muốn kiểm tra lại xem code thực tế viết ra có bám sát 100% với Plan đã thống nhất ban đầu không hay bị thiếu sót / đi lạc đề. Dùng cùng severity/verdict với `/review`. |

### 3. 📚 Nhóm Tài liệu (Documentation)

| Lệnh / Skill | Ý nghĩa cơ bản | Khi nào nên dùng? (Trường hợp áp dụng) |
| :--- | :--- | :--- |
| `/api-docs` | Sinh tài liệu cho Frontend | Khi làm xong 1 API mới, cần viết docs để ném cho Frontend tích hợp. Nó sẽ sinh ra file markdown `.md` (contract-only) lưu vào thư mục `api-docs/`, trace lỗi theo boundary code thật thay vì đoán lỗi sâu không verify. |
| `/code-docs` | Sinh tài liệu cho Backend | Khi viết xong 1 Feature phức tạp, cần viết giải thích flow chạy, thiết kế logic bên trong để anh em Backend sau này maintain dễ hiểu. File lưu vào thư mục `docs/`, ví dụ trong prompt đã được giữ trung lập để không kéo nhầm domain Zalo sang module khác. |
| `/commit-message`| Viết Git Commit tự động | Khi đã code xong và muốn commit, nhưng lười nghĩ câu commit. Lệnh này phân tích staged trước, fallback sang unstaged nếu chưa stage, đồng thời đọc cả untracked file liên quan để tránh commit message bỏ sót file mới. |

### 4. 🧮 Nhóm Kế hoạch & Phân rã (Planning)

| Lệnh / Skill | Ý nghĩa cơ bản | Khi nào nên dùng? (Trường hợp áp dụng) |
| :--- | :--- | :--- |
| `/task-breakdown`| Bẻ việc & Estimate (Skill) | Khi nhận được 1 Epic/Story lớn từ PM, cần chia nhỏ thành các task con và estimate Point (theo công thức Size × Effort) để đưa lên Jira. Lệnh này đảm bảo bẻ việc đúng chuẩn HRM, mỗi task không quá 2 Point, có tính reuse nhưng không giảm effort chỉ vì copy-paste logic. |

### 5. 🤖 Nhóm Hệ thống (Built-in Agent Commands)
*Đây là các lệnh có sẵn của công cụ AI (như Antigravity/Cursor/Claude) hỗ trợ tương tác chung.*

| Lệnh / Skill | Ý nghĩa cơ bản | Khi nào nên dùng? (Trường hợp áp dụng) |
| :--- | :--- | :--- |
| `/goal` | Hoàn thành mục tiêu dài hạn | Khi giao cho AI một task cực kỳ phức tạp (VD: "Chạy test toàn bộ app, fix hết tất cả lỗi hiển thị cho đến khi pass"). AI sẽ chuyển sang chế độ tự hành liên tục không nghỉ cho đến khi xong. |
| `/grill-me` | Phỏng vấn ngược lại bạn | Khi bạn có một ý tưởng chung chung nhưng chưa rõ kỹ thuật. Gọi lệnh này, AI sẽ liên tục đặt câu hỏi khó/sâu cho bạn để gọt giũa yêu cầu trước khi bắt tay vào code. |
| `/learn` | Ghi nhớ kinh nghiệm | Khi bạn vừa tự fix xong một lỗi setup hoặc chỉ cho AI 1 trick khó. Dùng lệnh này để AI "học" và nhớ mãi về sau, lần sau gặp nó sẽ tự biết cách làm. |
| `/schedule` | Lên lịch chạy định kỳ | Khi muốn AI tự động chạy 1 việc gì đó sau khoảng X phút (VD: "Cứ 10 phút check log 1 lần"). |

---

### 💡 Mẹo sử dụng hiệu quả
Quy trình (Workflow) khuyên dùng khi bạn nhận 1 task mới:

1. Gõ `/task-breakdown` để chia nhỏ task (nếu task to).
2. Gõ `/find-reuse` để xem có gì xài lại được không.
3. Nếu là Core use case mới hoàn toàn, gõ `/scaffold-feature` để tạo khung file; nếu là bugfix/sửa component có sẵn thì bỏ qua bước này.
4. Gõ `/implement` để AI viết logic, chạy quality gate và audit diff cuối.
5. Gõ `/scaffold-test` để tạo test.
6. Xong xuôi, gõ `/review`, `/review-vs-plan` nếu có Plan, và `/verify` để chốt chất lượng. Khi verify file cụ thể, truyền rõ file kèm base/range hoặc diff để AI không phải đoán phần thay đổi.
7. Cuối cùng, gõ `/api-docs`, `/code-docs` và `/commit-message` để hoàn tất bàn giao.
