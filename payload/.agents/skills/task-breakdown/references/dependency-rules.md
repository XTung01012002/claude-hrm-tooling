# Quy Tắc Dependency và Không Cộng Trùng Point

## 1. Không cộng trùng point
- Nếu một logic (ví dụ mapping DB, validation) đã được tính điểm ở một task, KHÔNG ĐƯỢC cộng điểm lại cho logic đó ở task khác hoặc file khác trong cùng một phiên bóc gộp.
- Tái sử dụng across nhiều file: Nếu file A đã bóc tính năng X, khi bóc file B gọi lại tính năng X, tính phần X ở file B là `reuse` (0 point cho implementation).

## 2. Quy tắc dependency trong Handler
- Handler chỉ được phụ thuộc vào Interface, không gọi trực tiếp Repository implementation.
- Đúng: `ChatRepositoryInterface`. Không nên: `ChatRepository`.
- Khi bóc task cho Handler:
  - Nếu phải tự viết mới Repository → tính cả Interface + Provider binding vào task, ghi rõ ở File/Dependency.
  - Nếu chỉ gọi lại Interface có sẵn → ghi `{Interface} (reuse)`.
  - Không cộng điểm cho logic implementation ẩn sau Interface nếu chỉ gọi từ Handler.
