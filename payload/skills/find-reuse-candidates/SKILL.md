---
name: find-reuse-candidates
description: Quét source code dự án để tìm logic/interface có thể tái sử dụng (Reuse-first). Dùng trước khi tạo class, interface, repository, helper hoặc module mới để tránh tạo mã trùng lặp.
---

# Find Reuse Candidates (Tìm kiếm ứng viên tái sử dụng)

Nguyên tắc cốt lõi số 2 của hệ thống là **Reuse-first + DRY**. Trước khi bạn định tạo một file mới, bạn PHẢI tự kích hoạt kỷ luật này để chặn việc tạo trùng lặp.

## Các vị trí ưu tiên tìm kiếm

Sử dụng các công cụ tìm kiếm (`grep`) để rà soát các khu vực sau xem đã có logic tương tự chưa:
1. `source/src/Core/Components/<Module>/Shared/`: Nơi chứa các interface, enum, helper dùng chung trong cùng module.
2. `source/src/Infrastructure/<Module>/Repositories/`: Nơi chứa các implementation truy xuất DB.
3. `source/src/Infrastructure/Shared/`: Các tiện ích dùng chung toàn hệ thống (như `Helper.php`).
4. Các class kết thúc bằng `Trait.php`.

## Hành động sau khi quét

- **Nếu tìm thấy ứng viên tái sử dụng:** Hãy sử dụng ngay ứng viên đó (inject interface, gọi helper/trait) thay vì tạo mới.
- **Nếu logic giống nhau nhưng nằm ở nhiều nơi:** Đề xuất tách logic đó ra `Shared/` hoặc `Trait` trước khi sử dụng.
- **Nếu KHÔNG tìm thấy ứng viên nào:** Bạn được phép tạo mới, nhưng phải tuân thủ đúng layering và convention của HRM.

*Lưu ý: Bạn có thể tham khảo thêm hướng dẫn chi tiết tại `docs/ai/prompts/find-reuse.md` nếu cần.*
