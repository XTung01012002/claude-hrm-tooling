# Format Output Bắt Buộc

Dòng nguồn dùng 1 trong 3 format sau, tùy theo input thực tế:

```markdown
> Từ task gốc: [BE] {tên task gốc}
```

```markdown
> Từ scope: {mô tả scope user cung cấp}
```

```markdown
> Từ User Story: {nội dung User Story}
```

Template output bắt buộc:

```markdown
## [DEV] {Tên công việc}

> {Dòng nguồn phù hợp}
> Scope: {phạm vi estimate}

| #   | Task                          | File/Dependency liên quan | Mô tả                                     | Size  | Effort   | Point       | Lý do point     |
| --- | ----------------------------- | ------------------------- | ----------------------------------------- | ----- | -------- | ----------- | --------------- |
| 1   | {Tên task tiếng Việt dễ hiểu} | {file/dependency}         | {mô tả làm gì, ở đâu, output verify được} | S/M/L | E/M/H    | {số cụ thể} | {lý do dễ hiểu} |
| 2   | ...                           | ...                       | ...                                       | ...   | ...      | ...         | ...             |
|     |                               |                           |                                           |       | **Tổng** | **{tổng}**  |                 |

**Tổng: {tổng} Point = {tổng × 100.000} VNĐ**

Ghi chú:

- {ghi chú nếu có phần ngoài scope}
- {ghi chú nếu point có thể giảm do reuse}
- {ghi chú nếu cần review codebase thực tế}
```

Trong output cuối cùng, cột `Point` phải là **một số cụ thể**, không để range như `0.125 - 0.25`.
