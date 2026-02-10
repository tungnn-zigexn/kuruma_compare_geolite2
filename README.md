# Công cụ so sánh GeoLite2-Country.mmdb hàng tháng

Công cụ **standalone** (không phụ thuộc Rails hay codebase tcv-web-v2) dùng để:

- Lấy file **trên GCS làm mốc (baseline)**.
- Tải file **mới từ MaxMind** (GeoLite2-Country).
- So sánh hai file (mẫu IP) và in **báo cáo % chênh lệch**.
- Dọn dẹp file tạm.

Chạy **1 lần/tháng** (cron hoặc Cloud Scheduler). Sau báo cáo, team xem % chênh lệch và quyết định có cập nhật file mốc trên Storage hay không.

Logic tải GCS/MaxMind và giải nén dựa trên các service đã xóa trong app: `cloud_downloader_service.rb`, `http_client_service.rb`, `tar_extractor_service.rb`, `max_mind_downloader_service.rb` — được tách lại thành các file trong thư mục này để dễ kiểm tra:

| File trong tool | Nguồn (đã xóa) |
|-----------------|----------------|
| `gcs_baseline_downloader.rb` | `app/services/ip_geolocation/cloud_downloader_service.rb` |
| `http_client_service.rb` | `app/services/ip_geolocation/http_client_service.rb` |
| `tar_extractor_service.rb` | `app/services/ip_geolocation/tar_extractor_service.rb` |
| `max_mind_downloader_service.rb` | `app/services/ip_geolocation/max_mind_downloader_service.rb` |

## Yêu cầu

- Ruby (khuyến nghị 3.x).
- Bundler: `bundle install` trong thư mục này.

## Cấu hình (ENV)

| Biến | Mô tả | Ví dụ |
|------|--------|-------|
| **GCS (baseline)** | | |
| `GCS_BUCKET` | Bucket GCS chứa file mốc | `my-bucket` |
| `GCS_OBJECT` | Đường dẫn object (file .mmdb) | `geolite2/GeoLite2-Country.mmdb` |
| `GOOGLE_APPLICATION_CREDENTIALS` | (Tùy chọn) Đường dẫn JSON key GCP | `/path/to/key.json` |
| **MaxMind (file mới)** | | |
| `MAXMIND_LICENSE_KEY` | License key tải GeoLite2 | *(bắt buộc)* |
| `MAXMIND_ACCOUNT_ID` | (Tùy chọn) Account ID nếu API yêu cầu | |
| **So sánh** | | |
| `SAMPLE_SIZE` | Số IP mẫu (random, seed cố định) | `50000` (mặc định) |
| `STEP` | Duyệt IPv4 theo bước thay vì random | `256` |
| `PROGRESS` | In tiến độ mỗi N IP (0 = tắt) | `10000` |

- **File mốc:** file trên GCS (ví dụ `gs://BUCKET/geolite2/GeoLite2-Country.mmdb`).
- **File mới:** tải từ MaxMind (GeoLite2-Country, tar.gz), giải nén lấy `.mmdb`.

Không hardcode bucket, object hay key trong code; chỉ dùng ENV hoặc file `.env` (file `.env` đã nằm trong `.gitignore`, không commit).

### Dùng file .env (import key sau)

1. Copy file mẫu thành `.env`:
   ```bash
   cd tools/compare-geolite2-monthly
   cp .env.example .env
   ```
2. Mở `.env` và điền các giá trị (bucket, license key, đường dẫn credentials…). Key/secret bạn cung cấp sau, chỉ cần điền vào đúng biến tương ứng trong `.env`.
3. Chạy tool: script tự load `.env` (nhờ gem `dotenv`), không cần `export` từng biến.

## Chạy

**Cách 1 — dùng .env (sau khi đã cp .env.example .env và điền key):**

```bash
cd tools/compare-geolite2-monthly
./bin/run
```

**Cách 2 — dùng script + export ENV:**

```bash
cd tools/compare-geolite2-monthly
export GCS_BUCKET=your-bucket
export GCS_OBJECT=geolite2/GeoLite2-Country.mmdb
export MAXMIND_LICENSE_KEY=your-license-key
./bin/run
```

**Cách 3 — gọi trực tiếp:**

```bash
cd tools/compare-geolite2-monthly
bundle install
# Có .env thì không cần export; không thì:
export GCS_BUCKET=your-bucket
export GCS_OBJECT=geolite2/GeoLite2-Country.mmdb
export MAXMIND_LICENSE_KEY=your-license-key
bundle exec ruby compare_mmdb.rb
```

- **Exit 0:** thành công; báo cáo in ra stdout.
- **Exit 1:** lỗi (tải GCS/MaxMind thất bại, không tìm thấy .mmdb trong archive, v.v.).

## Chạy hàng tháng (cron)

Ví dụ chạy vào 9h sáng ngày 1 hàng tháng, log ra file:

```cron
0 9 1 * * cd /path/to/tools/compare-geolite2-monthly && GCS_BUCKET=... GCS_OBJECT=... MAXMIND_LICENSE_KEY=... bundle exec ruby compare_mmdb.rb >> /var/log/compare_mmdb.log 2>&1
```

Cấu hình ENV có thể đặt trong script wrapper hoặc dùng file `.env` (không commit secret).

## Báo cáo

Script in ra:

- Nguồn file mốc (GCS) và file mới (MaxMind).
- Số IP kiểm tra, số có kết quả mỗi file, số có trong cả hai.
- Số cùng/khác mã quốc gia và **% chênh lệch**.
- Gợi ý: chênh &lt; 1% có thể giữ mốc; &gt; 5% nên cân nhắc cập nhật file mốc trên Storage.

Cập nhật file mốc trên Storage (nếu cần) làm thủ công hoặc bằng quy trình/job riêng.
