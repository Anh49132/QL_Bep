# AGENTS.md — Bếp Nhà

## Mục tiêu

Xây dựng bài tập lớn đề 04 "Hệ thống đặt món và xử lý tại bếp" của môn Phát triển ứng dụng phân tán trong 9 tuần. Mỗi tuần có phần chạy được, kiểm tra được và lịch sử Git phản ánh đúng công việc đã làm.

Người học dùng Windows, PowerShell và VS Code. Trao đổi bằng tiếng Việt, giải thích ngắn các quyết định và cung cấp lệnh có thể chạy trong PowerShell.

## Bắt đầu mỗi phiên

1. Đọc yêu cầu hiện tại của người dùng, đề bài, hướng dẫn chung, README và các hướng dẫn áp dụng trong repository.
2. Kiểm tra git status, cấu trúc dự án và mã nguồn liên quan trước khi sửa.
3. Xác định tuần hoặc chức năng được yêu cầu, phần đã hoàn thành và các phụ thuộc còn thiếu.
4. Tôn trọng thay đổi đang có của người dùng. Chỉ sửa file liên quan công việc.
5. Khi có quyền thao tác repository, trực tiếp triển khai, kiểm tra và sửa lỗi trong phạm vi được giao. Nếu môi trường chỉ hỗ trợ chat, cung cấp đường dẫn file, nội dung thay đổi và lệnh chạy cụ thể.
6. Tiếp tục công việc đã được người dùng cho phép. Chỉ hỏi khi thiếu thông tin hoặc có quyết định ảnh hưởng đáng kể đến kết quả.

## Yêu cầu bắt buộc theo đề

- Ngôn ngữ C#, nền tảng .NET 10, ASP.NET Core Minimal API.
- Client có chức năng xem món, tạo đơn và tra cứu đơn.
- Luồng xử lý gồm Client → Order API → RabbitMQ → Kitchen Worker → RabbitMQ → Notification Service → Client.
- API và Worker lưu dữ liệu vào database theo kiến trúc của đề.
- Kitchen Worker nhận và xử lý đơn bất đồng bộ theo thứ tự phù hợp.
- Có các trạng thái Pending, Preparing, Ready, Cancelled.
- Phát sự kiện khi trạng thái thay đổi và gửi thông báo realtime.
- Các service chạy độc lập.
- Mỗi service .NET có Dockerfile riêng. Toàn hệ thống có docker-compose.yml.
- Container giao tiếp nội bộ qua Docker network và service name.
- Connection string, URL service, địa chỉ broker và port tách khỏi mã nguồn.
- Có logging để theo dõi luồng xử lý và khả năng tiếp tục hoặc phục hồi khi thành phần tạm dừng.
- Có mã nguồn GitHub, báo cáo và README hướng dẫn build/chạy lại hệ thống.

API tối thiểu:

| Method | Route | Chức năng |
|---|---|---|
| GET | /menu | Danh sách món |
| POST | /orders | Tạo đơn |
| GET | /orders/{id} | Chi tiết và trạng thái đơn |
| GET | /orders | Danh sách đơn |

Các endpoint hoàn thành, hủy, lọc đơn theo bàn/lượt khách được bổ sung phục vụ giao diện. Ghi rõ hợp đồng API trong tài liệu khi triển khai.

## Lựa chọn triển khai của dự án

Các lựa chọn sau là định hướng của sản phẩm. Nếu mã nguồn đã có cách làm phù hợp, tái sử dụng và giải thích thay đổi cần thiết.

- Một quán ăn, khoảng 10 món và 5 bàn mẫu.
- PostgreSQL và EF Core.
- Web client dùng HTML/CSS/JavaScript, phục vụ từ ASP.NET Core Web App.
- SignalR cung cấp cập nhật realtime.
- Một database chung cho Order API và Kitchen Worker theo sơ đồ đề.
- Mỗi lần khách bấm gửi tạo một đơn độc lập, cho phép gọi thêm món.
- Mỗi màn hình xác định số bàn. Mã khách/lượt dùng bàn giúp phân biệt các lượt khách.
- Thông tin lượt dùng bàn phục vụ demo và lọc dữ liệu. Nếu có yêu cầu phân quyền, triển khai kiểm tra quyền phía server theo phạm vi mới.

Các project dự kiến:

| Project | Trách nhiệm |
|---|---|
| Order.Api | Thực đơn, tạo và tra cứu đơn, thao tác trạng thái, publish thông điệp/sự kiện |
| Kitchen.Worker | Nhận yêu cầu từ queue, tiếp nhận đơn Pending, chuyển Preparing, publish sự kiện |
| Notification.Service | Subscribe sự kiện và đẩy cập nhật qua SignalR |
| Restaurant.Web | Màn hình khách và màn hình bếp |

Tạo thư viện hợp đồng dùng chung khi nhiều project thực sự cần cùng hợp đồng. Chọn cấu trúc và số lớp phù hợp quy mô bài tập.

## Quy tắc dữ liệu và trạng thái

- Đơn có mã đơn, thông tin khách/lượt bàn, số bàn, thời điểm, ghi chú, trạng thái và chi tiết món.
- Giá dùng decimal. Server tính tiền từ giá lưu trong database.
- Chi tiết đơn lưu tên món và đơn giá tại lúc đặt để tra cứu lịch sử chính xác.
- Kiểm tra món tồn tại, đang bán, số lượng dương và giỏ có món.
- Lưu đơn và chi tiết nguyên vẹn trong một transaction.
- API tạo đơn ở Pending.
- Kitchen Worker tự chuyển Pending → Preparing.
- Nhân viên bếp thao tác chuyển Preparing → Ready.
- Khách được hủy Pending → Cancelled.
- Ready và Cancelled là trạng thái kết thúc trong phạm vi hiện tại.
- Chuyển trạng thái bằng cập nhật có điều kiện hoặc cơ chế đồng thời phù hợp. Khi hủy và tiếp nhận cạnh tranh, chỉ một thao tác thành công.
- Mỗi thành phần phát sự kiện cho thay đổi trạng thái mà nó thực hiện.
- Thao tác lặp và thông điệp giao lại phải giữ dữ liệu nhất quán.

## RabbitMQ, SignalR và phục hồi

- Phân biệt queue yêu cầu xử lý với queue sự kiện trạng thái để các consumer nhận đúng dữ liệu.
- Bắt đầu với một Kitchen Worker, xử lý tuần tự phù hợp nhu cầu demo.
- Thông điệp có định danh, mã đơn và thời điểm.
- Dùng queue bền vững, thông điệp persistent và xác nhận sau khi xử lý thành công.
- Kiểm tra lại trạng thái từ database trước khi tiếp nhận đơn.
- Hoàn thiện cơ chế phục hồi nếu lưu database thành công nhưng publish thất bại. Chọn giải pháp nhỏ phù hợp mã nguồn, kiểm tra bằng việc ngắt broker rồi khôi phục.
- Ghi nhận rõ hạn chế tạm thời trong các tuần chưa hoàn thiện phục hồi.
- Notification Service gửi đúng nhóm bếp và nhóm bàn/lượt khách.
- Client đăng ký lại nhóm và tải trạng thái mới từ API sau reconnect.
- Tránh để sự kiện cũ làm giao diện lùi trạng thái. Có thể tải lại dữ liệu từ API khi nhận thông báo.
- Log mã đơn, thao tác, kết quả và lỗi đủ để theo dõi xuyên các thành phần.

## Giao diện

Bám ảnh tham khảo Bếp Nhà đã được cung cấp. Dùng nền kem/trắng, xanh lá đậm, cam cho trạng thái đang chuẩn bị. Nhãn tiếng Việt rõ ràng, nút phù hợp màn hình cảm ứng.

Màn hình khách:
- Hiện số bàn, danh mục và danh sách món với ảnh, giá.
- Giỏ có tăng giảm số lượng, xóa món, ghi chú, tổng tiền và nút Gửi đơn.
- Hiện trạng thái đang gửi, lỗi và xác nhận thành công.
- Khóa nút gửi khi request đang chạy. Nếu mất kết nối làm kết quả gửi chưa rõ, hướng dẫn kiểm tra đơn trước khi gửi lại.
- Có mục Đơn của bàn cho lượt khách hiện tại và cách bắt đầu lượt khách mới trong demo.

Màn hình bếp:
- Các cột Chờ tiếp nhận, Đang chuẩn bị, Sẵn sàng.
- Thẻ đơn có mã, bàn, giờ, món, số lượng và ghi chú.
- Đơn chờ được Worker tự tiếp nhận.
- Đơn Preparing có nút Đã chuẩn bị xong.
- Có phản hồi lỗi khi thao tác thất bại.

Ảnh thiết kế dùng để tham khảo bố cục. Kiểm tra số liệu và trạng thái bằng dữ liệu thực tế. Dùng ảnh món có nguồn phù hợp, giữ ghi nhận nguồn khi cần.

## Tiến độ 9 tuần

Tuần là giai đoạn triển khai, xác định theo yêu cầu và trạng thái repository. Thực hiện tuần được giao cùng các phụ thuộc cần để chạy được. Nếu người dùng yêu cầu phạm vi lớn hơn, cập nhật kế hoạch theo yêu cầu.

| Tuần | Công việc | Điều kiện hoàn thành |
|---|---|---|
| 1 | Kiểm tra môi trường, phân tích, kiến trúc, tạo solution/project | Build được, project khởi động độc lập, README ban đầu |
| 2 | PostgreSQL, EF Core, migration, seed, GET /menu | Đọc thực đơn từ DB, khởi động lại còn dữ liệu |
| 3 | Tạo đơn, validation, danh sách và chi tiết | Tạo và đọc lại đúng đơn, kiểm tra dữ liệu sai |
| 4 | RabbitMQ, publisher, Kitchen Worker | Đơn chuyển Preparing, dừng/bật Worker tiếp tục xử lý |
| 5 | Giao diện khách, giỏ, gửi đơn, xem đơn theo bàn | Hai bàn tạo và theo dõi đúng đơn bằng API |
| 6 | Giao diện bếp, hoàn thành, hủy và đồng thời | Chuyển trạng thái đúng, hủy cạnh tranh nhất quán |
| 7 | Sự kiện, Notification Service, SignalR | Khách và bếp cập nhật tự động, reconnect tải đúng trạng thái |
| 8 | Docker toàn hệ thống, phục hồi và kiểm thử tích hợp | Compose chạy được, thử dừng thành phần và broker rồi phục hồi |
| 9 | Rà yêu cầu, báo cáo, README, demo cuối | Chạy từ bản clone mới, chuẩn bị demo và bản nộp |

Cập nhật tiến độ trong README sau từng mốc. Ghi những gì đã làm và đã kiểm tra thực tế.

## Git và commit

- Chia công việc thành các phần nhỏ, mỗi phần có kết quả có thể kiểm tra.
- Đọc git diff trước khi stage và git diff --cached trước khi commit.
- Chỉ stage file thuộc phần việc.
- Tên commit mô tả thay đổi thực tế, có thể dùng feat:, fix:, docs:, build:, chore:.
- Khi người dùng yêu cầu commit hoặc đã cho phép trong phiên, tạo commit sau kiểm tra. Nếu chỉ yêu cầu hướng dẫn, cung cấp lệnh tương ứng.
- Push khi người dùng yêu cầu hoặc đã cho phép. Giữ các commit đúng thời điểm thực hiện.
- Dùng .gitignore cho bin/, obj/, file môi trường local và thông tin bí mật. Có .env.example với giá trị mẫu.
- Bảo toàn lịch sử và thay đổi của người dùng.

Ví dụ tên commit:
- feat: implement menu API
- feat: create orders with input validation
- feat: process queued orders in kitchen worker
- feat: add table menu and cart interface
- feat: add kitchen dashboard and ready action
- feat: update table and kitchen screens with SignalR
- build: containerize services and complete compose setup

## Kiểm tra và báo cáo kết quả

- Build các project bị ảnh hưởng và chạy kiểm tra hiện có phù hợp thay đổi.
- Kiểm tra qua API hoặc giao diện bình thường.
- Bổ sung kiểm tra tự động cho lỗi dữ liệu, đồng thời hoặc phục hồi khi cần bắt hồi quy cụ thể.
- Với thay đổi trạng thái, kiểm tra dữ liệu sai, đơn không tồn tại, thao tác lặp và thao tác cạnh tranh.
- Với messaging/realtime, kiểm tra giao lại thông điệp, dừng Worker, reconnect client và tải lại trạng thái.
- Với Docker, phân biệt URL trình duyệt truy cập qua host và URL nội bộ giữa container.
- Ghi rõ lệnh đã chạy, kết quả thật, phần chưa kiểm tra và lý do.
- Nếu môi trường chặn chạy, nêu lỗi cụ thể và cung cấp bước kiểm tra tại máy người học.

Cuối phiên cung cấp bản tóm tắt ngắn gồm thay đổi, cách chạy trên PowerShell, kết quả kiểm tra, commit nếu có và việc tiếp theo.

## Nguồn yêu cầu

- Đề 04: https://chatgpt.com/library?file_id=libfile_d808d7f3c1a88191bc59a45fafda33df&account_id=personal
- Hướng dẫn chung: https://chatgpt.com/library?file_id=libfile_1b43cb2413688191b57f778c6b23efbe&account_id=personal
- Bộ prompt theo tuần: Bo_prompt_de_04_9_tuan.md
