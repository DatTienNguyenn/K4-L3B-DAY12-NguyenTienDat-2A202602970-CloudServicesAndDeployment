# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời chi tiết cho từng câu hỏi bên dưới.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Tiến Đạt  Mã học viên: 2A202602970

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu đặt giá trị mặc định là `"changeme"`, khi deploy lên server thật (production) mà người vận hành quên cấu hình biến môi trường `AGENT_API_KEY`, ứng dụng vẫn sẽ khởi động bình thường và báo trạng thái healthy. Lúc này, bất kỳ ai dò quét được URL công khai đều có thể dùng key mặc định `"changeme"` để gửi request không giới hạn, chiếm dụng tài nguyên và làm cạn kiệt ngân sách LLM của dự án. 

Ngược lại, với cơ chế "fail-fast", khi thiếu secret thì Pydantic sẽ ném ra `ValidationError` ngay lúc ứng dụng vừa khởi động. Ứng dụng lập tức dừng lại, container không vượt qua được healthcheck và không nhận traffic. Nhờ đó, lập trình viên phát hiện lỗi ngay trong quá trình deploy và kịp thời bổ sung biến môi trường trước khi hệ thống lộ ra ngoài Internet.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

**Dòng log JSON thu được từ thực tế:**
```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:55:55.735381+00:00", "user_id": "sv-test", "tokens_in": 41, "tokens_out": 45, "cost_usd": 3.315e-05}
```

**Hai việc làm được với log có cấu trúc:**
1. **Truy vấn, lọc và vẽ biểu đồ tự động bằng hệ thống quản lý log (như Elasticsearch, Datadog, Grafana CloudWatch):** Máy tính có thể parse các trường JSON trực tiếp để tính tổng chi phí (`sum(cost_usd)`), theo dõi số token trung bình tiêu thụ (`tokens_in`, `tokens_out`) theo thời gian thực hoặc lọc riêng lịch sử gọi của từng `user_id` mà không cần viết regex bóc tách chuỗi phức tạp.
2. **Thiết lập cảnh báo tự động (Alerting) theo ngưỡng chi phí:** Hệ thống có thể tự động bắn thông báo khẩn cấp (qua Slack/Email) nếu phát hiện một request có `cost_usd` vượt ngưỡng bất thường hoặc khi một `user_id` phát sinh chi phí quá nhanh, điều mà dòng in thô `print("đã trả lời xong")` hoàn toàn không cung cấp dữ liệu số liệu để thực hiện.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1020 MB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch khoảng ~750 MB bao gồm:
1. **Base image:** Bản 1-stage dùng `python:3.11` đầy đủ vốn chứa toàn bộ hệ điều hành Debian chuẩn với các công cụ biên dịch C/C++ (`gcc`, `g++`, `make`), các file header thư viện (`libc-dev`), bộ tài liệu (`man pages`) và các tiện ích hệ thống không cần thiết cho runtime. Trong khi đó, bản multi-stage dùng `python:3.11-slim` đã loại bỏ hoàn toàn các gói thừa này.
2. **Tách biệt build dependencies và runtime:** Ở stage `builder`, các thư viện Python được tải và biên dịch vào thư mục độc lập `/install` với cờ `--no-cache-dir`. Stage `runtime` chỉ copy đúng cây thư mục kết quả sang `/usr/local`, loại bỏ hoàn toàn pip wheel cache, file tạm sinh ra trong quá trình cài đặt và các công cụ build.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- **Với Dockerfile hiện tại:** Các layer trước lệnh copy mã nguồn gồm base image (`FROM`), thiết lập thư mục (`WORKDIR`), copy `requirements.txt` và toàn bộ lệnh cài đặt thư viện `RUN pip install ...` ở stage builder đều được Docker giữ nguyên và tận dụng lại từ cache (`CACHED`). Chỉ có layer `COPY . .` và các lệnh phía sau nó (`RUN chown`, `USER`,...) là phải chạy lại. Nhờ đó, việc build lại sau khi sửa code chỉ mất khoảng 1-2 giây.
- **Nếu đặt `COPY . .` lên trước `RUN pip install`:** Mỗi lần sửa một ký tự trong code, checksum của thư mục thay đổi làm cho layer `COPY . .` mất cache (invalidated). Docker bắt buộc phải thực thi lại toàn bộ các layer tiếp theo phía sau nó, khiến câu lệnh `RUN pip install` bị chạy lại từ đầu, phải tải và cài lại toàn bộ thư viện qua mạng, gây lãng phí băng thông và kéo dài thời gian build lên vài phút.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

1. **Chuỗi sự kiện khai thác khi chạy bằng root:**
   - Ứng dụng Python tồn tại một lỗ hổng bảo mật (ví dụ: Remote Code Execution qua lỗi insecure deserialization hoặc command injection).
   - Kẻ tấn công gửi payload để thực thi shellcode. Vì tiến trình container đang chạy dưới user `root` (UID 0), kẻ tấn công chiếm được quyền root đầy đủ bên trong container.
   - Từ đây, nếu máy chủ tồn tại lỗ hổng thoát container (container escape) như lỗ hổng nhân Linux, lỗ hổng của container runtime (`runc`), hoặc do cấu hình mount nhầm Docker socket (`/var/run/docker.sock`) vào container, kẻ tấn công có thể phá vỡ ranh giới cách ly (isolation).
   - Vì UID 0 trong container mặc định ánh xạ với UID 0 trên host OS, kẻ tấn công lập tức chiếm quyền `root` tối cao trên toàn bộ máy chủ vật lý/host.
2. **Lệnh `USER appuser` cắt đứt chuỗi:**
   - Lệnh `USER appuser` chuyển quyền thực thi của process sang một user thường không có đặc quyền (UID 10001).
   - Khi kẻ tấn công khai thác thành công lỗi code Python, chúng chỉ sở hữu quyền hạn chế của `appuser`: không thể ghi vào các file hệ thống của container, không có quyền sudo, và không có các Linux Capabilities cần thiết để tương tác với kernel nhằm thực hiện hành vi thoát container ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp.

**Giải thích cách đạt được:**
- Ở phút thứ nhất, người dùng chờ đến giây cuối cùng (`10:00:59`) và gửi dồn dập 10 request. Bộ đếm cố định ghi nhận 10 request trong phút 10:00 -> Vừa đúng hạn mức 10/phút nên được cho qua toàn bộ.
- Ngay khi đồng hồ nhảy sang giây đầu tiên của phút tiếp theo (`10:01:00`), hệ thống reset bộ đếm về 0. Người dùng lập tức gửi tiếp 10 request nữa. Bộ đếm ghi nhận 10 request trong phút 10:01 -> Vẫn hợp lệ.
- Tổng cộng: Trong khoảng thời gian chỉ 2 giây (từ `10:00:59` đến `10:01:00`), hệ thống đã tiếp nhận tới 20 request, gây ra đợt bùng nổ lưu lượng (traffic spike) gấp đôi hạn mức cho phép. Thuật toán Sliding Window (cửa sổ trượt 60 giây) loại bỏ hoàn toàn lỗ hổng này vì nó luôn tính tổng request trong khoảng thời gian `[now - 60, now]`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- **Khác biệt cốt lõi:** Rate limit bảo vệ **băng thông và khả năng chịu tải của hạ tầng** bằng cách giới hạn số lượng request trong một đơn vị thời gian (Requests Per Minute). Cost Guard bảo vệ **tài chính và ngân sách dự án** bằng cách kiểm soát tổng số tiền (USD tính theo lượng token tiêu thụ) tích lũy trong tháng.
- **Tình huống Rate limit cho qua nhưng Cost guard chặn:** Một người dùng cả tháng chỉ gửi duy nhất 1 request (tần suất cực thấp, hoàn toàn thỏa mãn hạn mức 10 req/phút). Tuy nhiên, request này chứa tài liệu dài kèm prompt 100.000 token, chi phí ước tính là 3.0 USD trong khi ngân sách còn lại của user này trong tháng chỉ còn 0.5 USD. Rate limit cho qua nhưng Cost guard chặn ngay và trả mã lỗi `402 Payment Required`.
- **Tình huống Cost guard cho qua nhưng Rate limit chặn:** Một người dùng viết script gửi liên tục 15 request trong vòng 3 giây, mỗi request chỉ hỏi câu ngắn "hi" tốn 0.00002 USD (tổng chi phí chỉ 0.0003 USD, còn rất xa hạn mức ngân sách 10.0 USD/tháng). Cost guard cho phép, nhưng Rate limit sẽ chặn từ request thứ 11 trở đi và trả mã lỗi `429 Too Many Requests`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự chuỗi sự kiện thảm họa:
1. Redis bị nghẽn mạng hoặc restart tạm thời, mất kết nối trong 30 giây.
2. Endpoint `/health` (liveness probe) của cả 3 container agent kiểm tra Redis thất bại và đồng loạt trả về HTTP `503`.
3. Orchestrator (Docker/Kubernetes) nhận thấy liveness probe trả về 503, kết luận rằng cả 3 container đã bị hỏng/deadlock, lập tức gửi tín hiệu kill và khởi động lại toàn bộ cụm container.
4. Cả 3 container khởi động lại cùng lúc. Lúc này Redis vẫn chưa kịp phục hồi (trong khung 30s sự cố). Khi vừa lên, container lại gọi kiểm tra Redis và tiếp tục nhận 503.
5. Orchestrator lại tiếp tục kill và khởi động lại chúng, đẩy toàn bộ cụm vào vòng lặp chết chóc (**CrashLoopBackOff / restart storm**). Mọi request đang xử lý bị hủy ngang, CPU và RAM của máy chủ tăng vọt do liên tục khởi tạo process mới, làm sập toàn bộ dịch vụ kể cả khi bản thân mã nguồn agent không có bất kỳ lỗi nào.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- **Khi lưu trong Redis (Stateless):** Bộ nhớ hội thoại nằm tập trung ngoài process. Dù Load Balancer định tuyến request đến bất kỳ container nào trong 3 container thì dữ liệu vẫn được đọc/ghi chung một nơi, `history_length` tăng đều đặn qua các lần hỏi: `0 -> 2 -> 4 -> 6...`.
- **Nếu lưu trong dict Python (Stateful trong RAM):** Mỗi container A, B, C sở hữu một vùng nhớ dict riêng biệt. Khi Load Balancer phân phối request theo thuật toán Round-Robin hoặc ngẫu nhiên:
  - Request 1 vào container A: `history_length = 0` (chỉ A lưu 2 message).
  - Request 2 rơi vào container B: B chưa từng thấy user này nên `history_length = 0` (B lưu 2 message).
  - Request 3 rơi vào container C: C cũng chưa có dữ liệu nên tiếp tục `history_length = 0`.
  - Request 4 rơi lại vào container A: A tìm thấy dữ liệu lượt 1 nên trả về `history_length = 2`.
  Kết quả là `history_length` nhảy lộn xộn, agent liên tục bị "mất trí nhớ", trả lời không ăn khớp với ngữ cảnh vừa trao đổi.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi gặp phải:** Sau khi deploy lên Railway và truy cập thử, endpoint `/health` trả về `200 OK` nhưng cả hai endpoint `/ready` và `/ask` đều trả về lỗi `HTTP 500 Internal Server Error`.
- **Cách tìm ra nguyên nhân:**
  Mở Railway Dashboard, vào service `agent` và kiểm tra tab **Deploy Logs**. Log hiển thị lỗi traceback của Python: Pydantic ném ra `ValidationError: 1 validation error for Settings -> agent_api_key -> Field required`. Nhận thấy `agent_api_key` là trường bắt buộc (không có default) nhưng chưa được cấu hình trong tab Variables của Railway, đồng thời biến `REDIS_URL` cũng chưa được trỏ sang database Redis trên cloud.
- **Cách sửa:**
  Vào tab **Variables** của service `agent` trên Railway Dashboard và cấu hình:
  1. Thêm biến `AGENT_API_KEY` với giá trị secret đã sinh ra.
  2. Thêm biến `REDIS_URL` sử dụng biến tham chiếu của Railway: `${{Redis.REDIS_URL}}` để tự động nối với database Redis vừa tạo.
  Sau khi lưu, Railway tự động kích hoạt redeploy và các endpoint `/ready`, `/ask` lập tức hoạt động trơn tru với mã HTTP `200` và `401`.
