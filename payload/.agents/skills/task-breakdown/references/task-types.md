# Mapping Kiến Trúc HRM API → Task

Khi bẻ việc cho feature CRUD mới hoặc tính năng bổ sung trong HRM API, có thể tham khảo mapping sau.
> ⚠️ Lưu ý: Các range trong mục này chỉ dùng để tham khảo nhanh. Khi đưa vào bảng estimate cuối, bắt buộc chọn **1 point cụ thể** theo ma trận Size × Effort; không để range trong cột Point.

## 1. Feature CRUD đầy đủ

| #   | Task                                       | File/Dependency liên quan                                   | Size | Effort | Point gợi ý  |
| --- | ------------------------------------------ | ----------------------------------------------------------- | ---- | ------ | ------------ |
| 1   | Tạo migration và model                     | `database/migrations`, `{Domain}Model.php`                  | S    | E      | 0.125 - 0.25 |
| 2   | Tạo entity và mapper                       | `{Domain}Entity.php`, `{Domain}Mapper.php`                  | S    | E      | 0.125 - 0.25 |
| 3   | Tạo repository interface và implementation | `{Domain}RepositoryInterface.php`, `{Domain}Repository.php` | M    | M      | 1            |
| 4   | Tạo flow thêm mới dữ liệu                  | Command, Handler, Validation, Controller                    | M    | E      | 0.5          |
| 5   | Tạo flow cập nhật dữ liệu                  | Command, Handler, Validation, Controller                    | M    | E      | 0.5          |
| 6   | Tạo flow xóa dữ liệu                       | Command, Handler, Validation, Controller                    | S    | E      | 0.125 - 0.5  |
| 7   | Tạo flow danh sách và tìm kiếm             | Query, Handler, Controller, SearchFilter                    | M    | M      | 1            |
| 8   | Tạo flow chi tiết dữ liệu                  | Query, Handler, Controller                                  | S    | E      | 0.125 - 0.5  |
| 9   | Đăng ký service provider                   | Provider, `bootstrap/providers.php`                         | S    | E      | 0.125        |

> Mức 0.125 chỉ dùng khi task gần như theo pattern có sẵn, không có relation phức tạp, không có permission riêng, không có business rule đặc biệt. Nếu có permission, relation phức tạp, validate theo company, transaction hoặc logic nghiệp vụ riêng thì phải tách task hoặc tăng point.

Tổng CRUD cơ bản: **3.625 Point** (tính theo mức thấp nhất của range). Điều chỉnh lên theo business logic thực tế.

## 2. Mapping Feature Sửa/Bổ Sung

> ⚠️ Các con số dưới đây là **tổng point ước tính cho cả feature**, không phải cho 1 task đơn lẻ. Mỗi task đơn trong feature đó vẫn phải tuân thủ giới hạn tối đa 2 Point và bắt buộc tách nếu vượt quá.
> **Không được đưa trực tiếp các số 3 hoặc 4 Point vào một dòng task.**

| Loại việc                | Scope thường gặp                             | Point tham khảo (cả feature) |
| ------------------------ | -------------------------------------------- | ---------------------------: |
| Thêm field mới           | Migration + Model + Validation + Resource    |                      0.5 - 1 |
| Thêm logic nghiệp vụ nhỏ | Handler + Validation                         |                    0.5 - 1.5 |
| Sửa query list/filter    | Repository + Filter + Resource               |                    0.5 - 1.5 |
| Thêm permission          | Middleware/Policy + Controller/Handler check |                        1 - 3 |
| Tích hợp module nội bộ   | Handler + Interface + Repository/Service     |                      1.5 - 3 |
| Tích hợp API bên ngoài   | Service + Handler + Error handling + Retry   |                        2 - 4 |
| Queue job xử lý async    | Job + DB update + Event + failed fallback    |                      1.5 - 4 |
| File upload/download     | File I/O + Storage + DB update               |                      1.5 - 4 |
