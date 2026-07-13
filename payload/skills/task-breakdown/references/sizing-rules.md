# Xác Định Size và Effort

## 1. Xác Định Size
Size đánh theo Technical Boundary, không đánh theo số file.

| Size  | Tiêu chí                                   | Ví dụ                                                                 |
| ----- | ------------------------------------------ | --------------------------------------------------------------------- |
| **S** | 1 boundary chính, logic gọn, ít dependency | Validate input, check permission, update 1 field DB, dispatch 1 event |
| **M** | 2 boundary hoặc 2 luồng phối hợp           | File I/O + S3, DB Write + Event, HTTP + DB                            |
| **L** | 3 boundary trở lên, nhiều bước điều phối   | HTTP + Validation + DB + S3 + Queue + Event                           |

Số file/method chỉ là dấu hiệu phụ.
- 1 file nhưng cross nhiều boundary → không phải Small.
- Nhiều file CRUD theo pattern có sẵn → chưa chắc là Large.
- 1 job xử lý HTTP download + S3 + DB transaction + fallback → có thể là Large dù chỉ 1 file.

## 2. Xác Định Effort
Effort đánh theo độ khó thực tế, rủi ro và edge case.

| Effort | Tiêu chí                                                                    | Ví dụ                                                                    |
| ------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **E**  | Logic đơn giản, pattern sẵn, ít edge case, reuse nhiều                      | CRUD cơ bản, map field, gọi helper/repository có sẵn                     |
| **M**  | Có business logic, validation, xử lý lỗi                                    | Check quyền, kiểm tra trạng thái, mapping attachment, update thread      |
| **H**  | Nhiều edge case, resource handling, async/concurrency, external integration | Stream file, S3 upload, retry, transaction, race condition, external API |

### Tăng effort nếu có:
- Legacy code khó hiểu
- Phụ thuộc nhiều module
- Cần research
- Cần test kỹ
- Có resource handling như stream/file descriptor
- Có external service như S3/Zalo API
- Có async flow như Queue/Event
- Có race condition/idempotency/concurrency

### Giảm effort nếu có:
- Có pattern đã verify và có thể áp dụng trực tiếp
- Chỉ gọi lại interface/helper/repository có sẵn
- Có template gần giống nhưng không sao chép business logic
- Task tương tự đã làm nhiều lần
- Không có business logic mới

Không giảm effort chỉ vì có thể copy-paste. Nếu phải nhân bản logic thay vì reuse, tính thêm rủi ro maintainability hoặc đề xuất tách shared logic theo `docs/ai/PROJECT-CONVENTIONS.md` §1.

## 3. Ma Trận Point
|                | **Easy (E)** | **Medium (M)** | **Hard (H)** |
| -------------- | -----------: | -------------: | -----------: |
| **Small (S)**  |        0.125 |           0.25 |          0.5 |
| **Medium (M)** |          0.5 |              1 |          1.5 |
| **Large (L)**  |            1 |            1.5 |            2 |

### Điều chỉnh ±0.125
Cho phép điều chỉnh ±0.125 khi task nằm ở ranh giới giữa 2 mức size hoặc effort, và có 1 yếu tố tăng/giảm nhỏ không đủ để đổi tier hoàn toàn.
Ví dụ: S/Hard (0.5) nhưng có thêm 1 điều kiện edge case nhỏ → 0.625.
Không được dùng ±0.125 để inflate/deflate tùy tiện mà không có lý do cụ thể trong cột **Lý do point**.

### Giới hạn trần point
Không được cộng thêm point cho task đã chạm mức tối đa **2 Point**.
- Nếu phần rủi ro tạo ra một phần việc có thể verify độc lập, phải tách thành task riêng thay vì cộng lên 2.125 Point.
- Không có task hợp lệ nào được vượt quá **2 Point**.

### Overlap trong ma trận
Một số combination cho cùng giá trị point, ví dụ S/Hard = M/Easy = 0.5. Chọn combination phản ánh đúng bản chất thực tế của task để cột **Lý do point** có ý nghĩa:
- Logic gọn nhưng cần xử lý edge case phức tạp → **S/Hard**
- Logic rộng hơn nhưng đơn giản, nhiều reuse → **M/Easy**

Quy đổi:
`1 Point = 100.000 VNĐ`
`0.125 Point = 12.500 VNĐ`

## 4. Nguyên Tắc Công Bằng
- Đánh theo effort thực tế, không inflate để tăng tiền, không deflate để giảm chi phí.
- Nếu phân vân giữa 2 mức → chọn mức thấp hơn.
- Nếu task chạm 2 Point và vẫn còn rủi ro tăng thêm → không cộng vượt 2 Point; ưu tiên tách phần có thể verify độc lập.
- Không cộng trùng point cho cùng một logic ở nhiều task.
- Nguyên tắc không cộng trùng cũng áp dụng across nhiều file trong cùng một phiên bóc gộp.
