# IBFT Log ETL - hướng dẫn cài đặt và chạy project

Project này dùng Pentaho Data Integration (PDI/Kettle) để đọc file log IBFT chứa XML, tách và chuẩn hóa các message request/response, sau đó lưu dữ liệu vào PostgreSQL và xuất hai file Excel: detail và summary.

- `detail`: mỗi dòng là một message/request trong log.
- `summary`: mỗi dòng là một giao dịch được tổng hợp theo `tracenumber`.

Bốn loại message đang được xử lý là `SGB_IBFT_DEP_REQ`, `IBFTDepositRequest`, `IBFTDepositResponse` và `SGB_IBFT_DEP_RES`. Các loại khác hiện được đưa vào nhánh unknown và không nạp vào hai bảng kết quả.

Điểm chạy chính duy nhất là:

```text
main/System_IBFT.kjb
```

Không cần và không nên chạy từng transformation `.ktr` riêng khi vận hành bình thường, vì nhiều transformation phụ thuộc biến và `BATCH_ID` do job chính truyền xuống.

## Cảnh báo trước khi chạy

- Job **di chuyển file nguồn** ra khỏi `data/`: thành công hoặc `SKIP` thì chuyển vào `archive/`; một số lỗi xử lý thì chuyển vào `error/`. Hãy dùng bản sao file khi test.
- Không chạy đồng thời hai instance của job.
- Cơ chế chống xử lý trùng chỉ dựa vào **tên file**. File đổi nội dung nhưng giữ nguyên tên vẫn có thể bị `SKIP`.

## Môi trường đã kiểm tra

Project đã chạy thành công trên môi trường sau:

| Thành phần | Phiên bản/cấu hình đã dùng |
|---|---|
| Hệ điều hành | Windows 64-bit |
| Pentaho Data Integration | `11.0.0.0-237` |
| Java | JDK `17.0.19` 64-bit |
| PostgreSQL | `18.3` |
| PostgreSQL JDBC | `42.5.6` |
| Run configuration | `Pentaho local` |

Nên dùng cùng PDI 11 và Java 17 để hạn chế lỗi khác phiên bản, đặc biệt ở các step đọc XML và ghi Excel.

## Cấu trúc thư mục

Phải giữ nguyên quan hệ giữa `main/` và các thư mục còn lại. Project có thể giải nén ở ổ đĩa hoặc đường dẫn khác; không bắt buộc phải là ổ `D:`.

```text
<PROJECT_ROOT>/
├── README.md
├── database/
│   └── schema.sql                 # DDL 5 bảng, không chứa dữ liệu/credential
├── main/
│   ├── System_IBFT.kjb            # entry point
│   ├── Proccess_one_file_IBFT.kjb # job xử lý một file; giữ nguyên tên đang viết như vậy
│   ├── List_input_file.ktr
│   ├── Read_Log.ktr
│   ├── Normalize_XML.ktr
│   ├── Prepare_Batch.ktr
│   ├── GroupBy_IBFT.ktr
│   ├── Load_DB.ktr
│   └── Export_XLSX.ktr
├── data/                           # inbox: chỉ quét file *.log ngay tại đây
├── output/
│   ├── detail/
│   └── summary/
├── archive/
├── error/
└── note/                           
```

Một số công cụ nén không giữ thư mục rỗng. Sau khi giải nén, cần kiểm tra và tạo lại `archive`, `output/detail`, `output/summary` nếu thiếu. Hai Excel Writer không tự tạo thư mục cha.

## Cấu trúc database

File `database/schema.sql` tạo 5 bảng trong schema `public` của PostgreSQL:

| Bảng | Mục đích |
|---|---|
| `etl_batch` | Theo dõi file đã xử lý, `batch_id`, thời gian bắt đầu và hoàn thành |
| `stg_event` | Dữ liệu XML sau khi được đọc và chuẩn hóa; dùng làm staging tạm |
| `stg_txn` | Dữ liệu tạm sau khi gom các message theo giao dịch |
| `ibft_detail` | Dữ liệu chi tiết, một dòng tương ứng một message/request |
| `ibft_summary` | Dữ liệu tổng hợp, một dòng tương ứng một giao dịch trong một batch |

Các ràng buộc chính:

- `etl_batch.batch_id` là khóa chính.
- `etl_batch.source_file_name` là duy nhất, dùng để tránh nạp lại cùng một tên file.
- `ibft_detail.batch_id` và `ibft_summary.batch_id` tham chiếu đến `etl_batch.batch_id`.
- `ibft_summary` không cho phép trùng cặp `(batch_id, tracenumber)`.
- Hai bảng staging không đặt khóa chính vì chỉ chứa dữ liệu tạm và được làm sạch trước mỗi lượt xử lý.

## Cài đặt nhanh

### 1. Tạo database và chạy file schema

Tạo database PostgreSQL tên `ibft_analytics` hoặc dùng database khác do DBA cấp. Sau đó kết nối vào database đó và chạy [database/schema.sql](database/schema.sql). File này chỉ tạo 5 bảng cùng các constraint, không chứa dữ liệu.

`schema.sql` được viết theo cú pháp PostgreSQL và chỉ nên chạy lần đầu trên database trống. 




Ví dụ với `psql` trên Windows:

```powershell
$projectRoot = (Resolve-Path '.').Path
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
  --host localhost `
  --port 5432 `
  --username postgres `
  --dbname ibft_analytics `
  --file (Join-Path $projectRoot 'database\schema.sql')
```

### 2. Tạo Shared Database Connection trong Spoon

Tất cả job/transformation tham chiếu connection bằng đúng tên:

```text
PG_IBFT_ANALYTICS
```

Connection không được nhúng trong project. Trong Spoon, tạo một **Shared Database Connection** với tên chính xác như trên, chọn PostgreSQL/Native, nhập thông tin của môi trường rồi bấm **Test**.

Cấu hình máy phát triển để tham khảo:

| Thuộc tính | Giá trị |
|---|---|
| Connection name | `PG_IBFT_ANALYTICS` |
| Connection type | PostgreSQL |
| Access | Native |
| Host | `localhost` |
| Port | `5432` |
| Database | `ibft_analytics` |
| User | `postgres` |
| Password | `Mật khẩu của PostgreSQL user trên máy chạy` |

**Tên connection** phải giữ nguyên nếu không muốn sửa đồng loạt các step.

### 3. Chuẩn bị input

Đặt file nguồn trực tiếp tại:

```text
<PROJECT_ROOT>/data/<ten-file>.log
```

Quy tắc quét file hiện tại:

- Chỉ nhận tên kết thúc chính xác bằng `.log` theo regex `.*\.log$`.
- Không quét thư mục con.
- Các file se được sắp xếp tăng dần theo thời gian sửa, sau đó theo tên, và được xử lý tuần tự qua `List_input_file.ktr`

### 4. Chạy bằng Spoon

1. Mở `<PDI_HOME>/Spoon.bat`.
2. Mở `<PROJECT_ROOT>/main/System_IBFT.kjb`.
3. Chọn **Run** với run configuration `Pentaho local`.
4. Theo dõi tab **Logging** và xác nhận job kết thúc với trạng thái success.

Không cần truyền parameter khi chạy từ `System_IBFT.kjb`.

## Cách xác định trạng thái file

`Prepare_Batch.ktr` tra cứu `source_file_name` trong `etl_batch` và trả về một trong ba trạng thái:

| Trạng thái | Điều kiện | Cách xử lý |
|---|---|---|
| `NEW` | Chưa có tên file trong `etl_batch` | Tạo batch mới rồi xử lý |
| `RETRY` | Đã có batch nhưng `completed_at` còn `NULL` | Dùng lại `batch_id`, xóa dữ liệu dở của batch rồi nạp lại |
| `SKIP` | Đã có batch và `completed_at` đã có giá trị | Không nạp lại dữ liệu; chuyển file vào `archive/` |

## Luồng xử lý

```text
data/*.log
    |
    v
System_IBFT.kjb
    |
    +--> List_input_file.ktr
    |      Liệt kê và sắp xếp input
    |
    +--> Proccess_one_file_IBFT.kjb      (mỗi file một lượt, tuần tự)
           |
           +--> Read_Log.ktr
           |      +--> Normalize_XML.ktr
           |      +--> TRUNCATE + ghi public.stg_event
           |
           +--> Prepare_Batch.ktr
           |      +--> NEW   : tạo etl_batch mới
           |      +--> RETRY : dùng lại batch chưa completed
           |      +--> SKIP  : batch đã completed
           |
           +--> SKIP ----------------------------> archive/<tên file>
           |
           +--> NEW/RETRY
                  |
                  +--> xóa detail/summary cũ theo BATCH_ID
                  +--> GroupBy_IBFT.ktr
                  |      TRUNCATE + ghi public.stg_txn
                  +--> Load_DB.ktr
                  |      ghi public.ibft_detail và public.ibft_summary
                  +--> Export_XLSX.ktr
                  |      ghi output/detail và output/summary
                  +--> cập nhật etl_batch.completed_at
                  +--> archive/<tên file>

                  GroupBy/Load/Export lỗi --> error/<tên file> --> Abort
```


## Kiểm tra sau khi chạy

```sql
SELECT batch_id, source_file_name, started_at, completed_at
FROM public.etl_batch
ORDER BY batch_id DESC

SELECT batch_id, COUNT(*) AS detail_rows
FROM public.ibft_detail
GROUP BY batch_id
ORDER BY batch_id DESC

SELECT batch_id, COUNT(*) AS summary_rows
FROM public.ibft_summary
GROUP BY batch_id
ORDER BY batch_id DESC
```

## Xử lý sự cố thường gặp

| Hiện tượng | Nguyên nhân thường gặp | Cách kiểm tra |
|---|---|---|
| `PG_IBFT_ANALYTICS not found` | Chưa tạo shared connection hoặc đặt sai tên | Mở Spoon, kiểm tra đúng tên `PG_IBFT_ANALYTICS` rồi bấm **Test** |
| PDI không kết nối được PostgreSQL | Sai host, port, user hoặc password | Thử đăng nhập cùng thông tin bằng pgAdmin/psql rồi kiểm tra lại connection |
| Không tạo được file Excel | Thiếu thư mục đầu ra hoặc file đang được mở | Tạo `output/detail`, `output/summary` và đóng file Excel cũ |
| Job không tìm thấy file | File không nằm trực tiếp trong `data/` hoặc không kết thúc bằng `.log` | Kiểm tra lại tên và vị trí file |

## Giới hạn hiện biết

- Chỉ hỗ trợ bốn XML root nêu trên; loại khác bị bỏ.
- Parser phụ thuộc marker log và phần mở đầu XML chính xác.
- Không có bước kiểm tra file đã ghi xong/stable trước khi lấy xử lý.
- Chống trùng theo tên file, không theo nội dung hoặc modified time.
- Staging dùng chung và bị truncate, nên chỉ hỗ trợ một instance tại một thời điểm.
- `Prepare_Batch` hiện chạy sau `Read_Log`, nên một file đã hoàn thành vẫn được đọc vào staging trước khi đi nhánh `SKIP`.
