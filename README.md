# Bếp Nhà — Hệ thống đặt món và xử lý tại bếp

Bài tập lớn đề 04, môn Phát triển ứng dụng phân tán. C#/.NET 10, Minimal API.

**Hiện tại: tuần 2 đã có PostgreSQL, migration/seed và GET /menu.**
Xem [cách chạy tuần 2 và kết quả kiểm tra](#tuần-2--postgresql-ef-core-và-thực-đơn).
Các phần tuần 1 bên dưới giữ lại kết quả kiểm tra tại thời điểm thực hiện.

## A. Phân tích yêu cầu và kiến trúc

Xem [tác nhân, phạm vi, dữ liệu, sơ đồ kiến trúc, trạng thái và kế hoạch 9 tuần](docs/yeu-cau-va-kien-truc.md).
Luồng đích: Client → Order API → RabbitMQ → Kitchen Worker → RabbitMQ → Notification Service → Client.
API và Worker dùng chung PostgreSQL; SignalR cung cấp realtime.

## B. Khởi tạo solution và project

Solution `BepNha.slnx`, mã nguồn `src/`, chưa cần thư viện hợp đồng chung.

| Project | Vai trò đích | URL local |
|---|---|---|
| Order.Api | Minimal API cho thực đơn/đơn và publisher | http://localhost:5101 |
| Kitchen.Worker | Generic Host/BackgroundService tiếp nhận đơn | Không mở port HTTP |
| Notification.Service | Nhận sự kiện, gửi SignalR | http://localhost:5102 |
| Restaurant.Web | ASP.NET Core phục vụ HTML/CSS/JS | http://localhost:5103 |

Ba web dùng bộ khung ASP.NET Core Empty; Restaurant.Web phục vụ HTML tĩnh, chưa cần Razor.
Mỗi web có `GET /health` trả JSON `{ service, status: "ok" }`; chỉ kiểm tra tiến trình,
chưa kiểm tra DB/broker. Order.Api/Notification.Service có `GET /` trả `{ service, week: 1 }`.
Restaurant.Web có trang tiếng Việt tại `/`, `GET /config` chỉ xuất hai URL công khai.
Worker in log khởi động và chờ dừng, chưa lấy đơn từ queue.

### Môi trường thực tế ngày 23/11/2026

| Thành phần | Kết quả |
|---|---|
| .NET SDK | 10.0.403, ASP.NET Core runtime 10.0.14, Windows x64 |
| Git | 2.56.1.windows.1 |
| Local repo | Đã có main và commit đầu tiên; không khởi tạo lại |
| Remote | origin: https://github.com/Anh49132/QL_Bep.git |
| Docker CLI | docker version/info/compose version đều báo không nhận lệnh |
| Docker Desktop/Engine | Chưa xác nhận; không thấy tiến trình/dịch vụ, mục cài đặt trong registry hoặc docker.exe ở Program Files và ổ D trong phiên công cụ |
| Compose | Chưa kiểm tra được vì chưa tìm thấy CLI |

Người dùng đã cài Docker Desktop; kết quả phiên công cụ chưa đủ kết luận máy chưa cài.
Mở Docker Desktop, chờ Engine hoạt động, đóng/mở VS Code để cập nhật PATH rồi kiểm tra:

```powershell
Get-Command docker
docker version
docker info
docker compose version
```

`docker version` cần hiện cả Client và Server để xác nhận Engine. Tuần 1 chạy trực tiếp
bằng .NET, chưa cần Docker, DB hay broker.

### Build và chạy PowerShell

Mở Terminal tại thư mục gốc dự án:

```powershell
dotnet --info
git --version
dotnet restore BepNha.slnx
dotnet build BepNha.slnx --no-restore
```

Restore đầu cần Internet để tải Microsoft.Extensions.Hosting 10.0.0 cho Worker.
Mở bốn Terminal riêng tại thư mục gốc, mỗi Terminal chạy một lệnh sau:

```powershell
dotnet run --project src/Order.Api --no-launch-profile
```

```powershell
dotnet run --project src/Kitchen.Worker --no-launch-profile
```

```powershell
dotnet run --project src/Notification.Service --no-launch-profile
```

```powershell
dotnet run --project src/Restaurant.Web --no-launch-profile
```

Mở http://localhost:5103; Ctrl+C để dừng. Kiểm tra từ Terminal khác:

```powershell
Invoke-RestMethod http://localhost:5101/health
Invoke-RestMethod http://localhost:5102/health
Invoke-RestMethod http://localhost:5103/health
Invoke-RestMethod http://localhost:5103/config
```

Chạy lại kiểm tra khởi động độc lập (dừng các ứng dụng đang chạy trên các port này trước):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week1.ps1
```

Script khởi động từng project riêng, kiểm tra HTTP/nội dung hoặc log Worker, dừng tiến
trình do chính script tạo; log trong `.artifacts/week1/` được gitignore. Build Debug trước khi chạy.

### Cấu hình và bí mật

Khóa `Urls` trong mỗi appsettings.json đặt port. `Services` của Restaurant.Web đặt URL
trình duyệt sẽ gọi. `.env.example` là mẫu; dotnet run **không tự đọc .env**.
Chưa khai báo tài khoản DB/broker vì chưa dùng. Sau này bí mật đặt ở môi trường hoặc
file local được gitignore; `/config` không được xuất bí mật.

Ghi đè trong đúng Terminal của từng ứng dụng:

```powershell
# Terminal Order.Api
$env:URLS = "http://localhost:5201"
dotnet run --project src/Order.Api --no-launch-profile
```

```powershell
# Terminal Restaurant.Web: đổi URL API tương ứng
$env:Services__OrderApiUrl = "http://localhost:5201"
dotnet run --project src/Restaurant.Web --no-launch-profile
```

Biến áp dụng cho Terminal hiện tại/tiến trình con. Bỏ bằng `Remove-Item Env:URLS`
hoặc `Remove-Item Env:Services__OrderApiUrl` tại Terminal đã đặt biến.

Tài liệu chính thức: [WebApplication và URL](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/webapplication?view=aspnetcore-10.0),
[cấu hình môi trường](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-10.0),
[chẩn đoán Docker Desktop](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/).

### Kết quả kiểm tra

- `dotnet build BepNha.slnx --nologo`: thành công, 0 cảnh báo, 0 lỗi. Lần đầu bị NU1301
  do sandbox chặn NuGet; chạy lại sau khi được cấp quyền mạng đã restore/build thành công.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week1.ps1`: cả bốn
  project PASS khi chạy lần lượt, không cần service còn lại. Ba `/health`, hai endpoint
  gốc, trang HTML tiếng Việt và `/config` phản hồi đúng; Worker ghi log Application started.
- Biến môi trường: đã chạy Restaurant.Web trên port 5194 bằng `URLS`, xác nhận
  `/config` trả OrderApiUrl port 5191 từ `Services__OrderApiUrl`. Dùng `URLS` để ghi đè
  trực tiếp khóa `Urls`; phép thử `ASPNETCORE_URLS` không ghi đè được khóa appsettings này.
- `git diff --check`: không có lỗi khoảng trắng. README cũ là UTF-16, đã đổi sang UTF-8
  để dễ đọc/chỉnh sửa tài liệu và xem diff về sau.
- Docker/Compose: chưa xác minh được vì không tìm thấy CLI trong phiên này.

## Git và GitHub

Repo hiện đã kết nối origin; không thêm lại remote:

```powershell
git status
git remote -v
git log --oneline -5
```

Nếu khởi tạo ở thư mục mới: tạo repo trống trên GitHub, không thêm README/.gitignore
tự động, rồi chạy trong thư mục dự án (chỉ khi chưa có Git/remote):

```powershell
git init
git branch -M main
git remote add origin https://github.com/Anh49132/QL_Bep.git
```

Nếu repo đã có mã nguồn, dùng `git clone https://github.com/Anh49132/QL_Bep.git`.
Chỉ push sau khi có commit. Chưa tự commit/push trong phiên này; đề xuất hai phần:

```powershell
git diff
git add README.md docs/yeu-cau-va-kien-truc.md
git diff --cached
git commit -m "docs: define requirements and system architecture"

git add .gitignore .env.example BepNha.slnx src scripts
git diff --cached
git commit -m "chore: initialize solution and service projects"

git push -u origin main
```

## Tuần 2 — PostgreSQL, EF Core và thực đơn

### A. Database, migration và dữ liệu mẫu

`docker-compose.yml` hiện chạy **chỉ PostgreSQL 17 Alpine**. Named volume
`bep-nha_postgres_data` lưu `/var/lib/postgresql/data`; cổng mặc định 5432 chỉ bind
127.0.0.1. Các ứng dụng .NET vẫn chạy trực tiếp trên Windows; container hóa toàn bộ
service thuộc tuần 8. Compose tự tạo Docker network mặc định cho dự án.

Model và DbContext nằm trong `src/Order.Api/Models` và `src/Order.Api/Data` vì hiện chỉ
API sử dụng. Khi Worker cần truy cập DB ở tuần 4 sẽ xem xét chia sẻ phần thực sự cần.
Không thêm thư viện hợp đồng dùng chung ở tuần này.

| Bảng | Dữ liệu chính |
|---|---|
| MenuItems | Tên, giá decimal/numeric(18,2), danh mục, ảnh/alt/nguồn, đang bán |
| RestaurantTables | Số bàn (khóa chính), tên bàn |
| TableSessions | UUID lượt bàn, số bàn, mã khách, bắt đầu/kết thúc UTC |
| Orders | UUID, mã đơn duy nhất, mã lượt, số bàn, mã khách, thời điểm UTC, trạng thái, ghi chú, tổng decimal |
| OrderItems | Mã đơn/món, bản chụp tên/đơn giá decimal, số lượng, ghi chú |

Quan hệ và giới hạn: [thiết kế database tuần 2](docs/database-tuan-2.md).
Hai migration được tạo bằng dotnet-ef: `InitialRestaurant` tạo schema,
`ReserveMenuIds` dành mã 1–10 cho seed và bắt đầu sequence món mới từ 1000.

Seed 10 món Việt và 5 bàn (1–5) dùng `UseSeeding`/`UseAsyncSeeding`, được bảo vệ bởi
migration lock. Chỉ thêm mã còn thiếu, không đổi tên/giá/trạng thái món đã tồn tại,
không tạo lượt khách hay đơn giả. Chạy database update lại không nhân bản dữ liệu.
Seed chỉ chạy khi migrate/update, không tự chạy ở mỗi request hoặc lần bật API thường.

### Cấu hình local lần đầu

Máy đang làm việc đã có `.env` với mật khẩu ngẫu nhiên, được gitignore; **không copy
đè file đó**. Khi clone mới hoặc chưa có `.env`, chạy:

```powershell
Copy-Item .env.example .env
code .env
```

Trong `.env`, thay cả hai chỗ `replace_with_local_password` bằng cùng một mật khẩu
local; giữ POSTGRES_DB/USER/PORT và connection string khớp nhau. File dùng dạng
`KEY=value` không có dấu nháy, không nội suy biến. Mật khẩu mẫu đơn giản nên dùng
chuỗi chữ/số ngẫu nhiên; nếu tự dùng ký tự đặc biệt, tuân theo cú pháp connection string Npgsql.

`appsettings.json` có connection string mẫu **không chứa mật khẩu**; cấu hình thật
được ghi đè bởi `ConnectionStrings__RestaurantDb`. Compose đọc `.env` tự động;
dotnet cần biến môi trường. Script sau nạp `.env` vào Terminal hiện tại, không in giá trị.

```powershell
# Chạy ở thư mục gốc. Chính sách này chỉ áp dụng Terminal hiện tại.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Import-LocalEnvironment.ps1

docker version
docker compose version
docker compose up -d --wait postgres
docker compose ps

dotnet tool restore
dotnet restore BepNha.slnx
dotnet build BepNha.slnx --no-restore
dotnet ef database update --project src/Order.Api --no-build
```

Đã có migration trong Git, không tạo lại InitialRestaurant sau clone. Công cụ
dotnet-ef và Design được chốt 10.0.15, cùng phiên bản runtime EF mà Npgsql 10.0.4 yêu cầu.
Không nâng sang EF 11 cho dự án .NET 10 này.

Có thể chạy migration và seed bất đồng bộ bằng lệnh thay thế (rồi tiến trình thoát):

```powershell
dotnet run --project src/Order.Api --no-build --no-launch-profile -- --migrate
```

URL database khi API chạy trên Windows: `Host=localhost;Port=5432`.
Sau này nếu API chạy trong cùng Compose network: `Host=postgres;Port=5432`.
Nếu đổi POSTGRES_PORT thì cập nhật Port của connection string trên host tương ứng.
Đổi mật khẩu trong `.env` không đổi mật khẩu role đã nằm trong volume; giữ cấu hình
khớp DB hiện có hoặc chủ động đổi mật khẩu bằng PostgreSQL.

### B. GET /menu và kiểm tra

Trong Terminal đã nạp môi trường ở trên:

```powershell
dotnet run --project src/Order.Api --no-build --no-launch-profile
```

Trong Terminal khác:

```powershell
$menu = Invoke-RestMethod http://localhost:5101/menu
$menu | Format-Table id, name, price, category
$menu.Count
Start-Process http://localhost:5101/images/menu-placeholder.svg
```

`GET /menu` trả HTTP 200 và mảng JSON các món `IsAvailable=true`, sắp theo danh mục
rồi mã. Trên database mẫu mới có 10 món. Nếu không còn món đang bán, trả `[]`.
Phản hồi mỗi món gồm:

```json
{
  "id": 1,
  "name": "Cơm gà",
  "price": 45000.00,
  "category": "Cơm",
  "imageUrl": "/images/menu-placeholder.svg",
  "imageAlt": "Hình minh họa đĩa thức ăn, chưa phải ảnh món thực tế",
  "imageSource": "Bếp Nhà — minh họa SVG tự tạo"
}
```

Giá tính theo VND. URL ảnh tương đối theo **Order.Api**, không phải Restaurant.Web.
SVG tự tạo đi kèm repo, không cần tải ảnh bên ngoài; đây là ảnh minh họa chung,
chưa phải ảnh chụp từng món. Không trả entity/navigations hoặc dữ liệu khách hàng.
Database lỗi thì API trả lỗi 500 dạng Problem Details và ghi log, không giả lập menu.
`/health` vẫn chỉ kiểm tra tiến trình như tuần 1.

### Kiểm thử và dữ liệu sau restart

Sau build Debug, chạy trên database demo mới có đủ 10 món đang bán:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week2.ps1 -RestartDatabase
```

Script dùng port API 5192, nạp `.env`, migrate/seed cả hai cách, kiểm tra database và
HTTP bình thường. Nó tạo một món kiểm tra không bán, xác nhận API không trả món đó,
rồi **tạo lại container postgres của dự án** nhưng giữ volume. Sau restart API, nó
xác nhận dữ liệu ngoài seed vẫn tồn tại (không thể che lỗi bằng seed lại) và dọn món
kiểm tra. Các kiểm tra constraint/snapshot chạy trong transaction rồi rollback.
Bỏ `-RestartDatabase` nếu chỉ muốn kiểm tra restart API, không tạo lại container.
Chỉ chạy trên DB demo; script cần ngắt kết nối tạm thời khi tạo lại postgres.
Log API ở `.artifacts/week2/`, không vào Git.

Kiểm tra thủ công việc giữ volume:

```powershell
docker compose restart postgres
docker compose up -d --wait postgres
Invoke-RestMethod http://localhost:5101/menu
```

Ctrl+C rồi chạy lại API và gọi `/menu`; không cần chạy migration lại chỉ để restart.
`docker compose down` giữ volume; **không dùng `down -v` khi muốn giữ dữ liệu**.

### Kết quả thực tế ngày 25/11/2026

- Docker Desktop 4.100.1, Engine 29.9.3 (Linux/amd64), Compose v5.7.1; postgres healthy.
- `dotnet build BepNha.slnx`: đạt, 0 cảnh báo/0 lỗi; bốn project tuần 1 vẫn chạy độc lập.
- Áp dụng hai migration thành công; kiểm tra đủ 10 mã món mẫu và 5 bàn.
- Migration/seed đồng bộ và bất đồng bộ, chạy lặp: đạt, không trùng dữ liệu.
- Script tuần 2: đạt HTTP `/menu`, trường JSON, ảnh SVG và lọc món không bán.
- Đạt decimal, tên/giá lịch sử độc lập thực đơn, chặn quantity=0, giá âm,
  trạng thái sai và bàn không khớp lượt khách tại database.
- Đạt restart API và force-recreate PostgreSQL giữ volume; dữ liệu kiểm tra ngoài seed còn.
- `dotnet ef migrations has-pending-model-changes`: không có thay đổi model chưa migration.

Các API tạo/đọc đơn và logic validation/transaction phía server thuộc tuần 3,
chưa triển khai ở tuần 2. Kiểm tra snapshot hiện xác nhận schema lưu độc lập,
chưa phải kiểm thử tạo đơn qua HTTP. Worker, RabbitMQ và SignalR chưa nối DB/broker.

Nguồn chính thức: [Npgsql EF Core 10](https://www.npgsql.org/efcore/release-notes/10.0.html),
[UseSeeding/UseAsyncSeeding và migration lock](https://learn.microsoft.com/en-us/ef/core/modeling/data-seeding),
[PostgreSQL Docker image/volume](https://hub.docker.com/_/postgres).

### Commit gợi ý tuần 2

Chưa tự stage/commit/push. Xem diff cả file mới trong VS Code rồi có thể chia hai phần:

```powershell
git status --short
git diff
git add .env.example .config/dotnet-tools.json docker-compose.yml src/Order.Api/Order.Api.csproj src/Order.Api/appsettings.json src/Order.Api/Models src/Order.Api/Data scripts/Import-LocalEnvironment.ps1
git add -p src/Order.Api/Program.cs
git diff --cached
git commit -m "feat: add database models and sample data"

git add src/Order.Api/Program.cs src/Order.Api/wwwroot scripts/Test-Week2.ps1 scripts/week2-checks.sql README.md docs/database-tuan-2.md docs/yeu-cau-va-kien-truc.md
git diff --cached
git commit -m "feat: implement menu API"
git push
```

Tại bước `git add -p`, dùng `s` để tách hunk nếu cần, chọn `y` cho using, đăng ký
DbContext/seed, Problem Details, static files và chế độ `--migrate`; chọn `n` cho
khối `app.MapGet("/menu", ...)` để giữ endpoint sang commit thứ hai. Nếu khó chọn,
dùng Stage Selected Ranges trong VS Code rồi kiểm tra `git diff --cached`.
Sau phần A, build và `dotnet ef database update` đã chạy được; sau phần B có GET /menu.

## Tiến độ

Tuần 1 và 2 hoàn thành; tuần 3 tiếp theo là tạo/tra cứu đơn, validation và transaction.
RabbitMQ, SignalR, giao diện nghiệp vụ, Dockerfile cho từng service và phục hồi sẽ
được thực hiện ở các tuần tương ứng trong tài liệu kiến trúc.
