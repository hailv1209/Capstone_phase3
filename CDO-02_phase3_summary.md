# Tóm tắt yêu cầu Phase 3 cho nhóm CDO-02

## 1. Nhóm mình đang ở đâu

- `CDO-02` thuộc `TF3`.
- `TF3` gồm: `AIO02`, `CDO01`, `CDO02`.
- Đây không phải bài làm theo checklist sẵn, mà là bài toán **tiếp quản một hệ thống AI đang chạy**, tự đánh giá, tự ưu tiên, tự vận hành, tự bảo vệ quyết định.

## 2. Mục tiêu tổng thể của 3 tuần tới

Nhóm cần chứng minh mình có thể **own một service production** theo kiểu đi làm thật:

- Dựng hệ thống từ source lên chạy trên account/cluster của TF.
- Giữ hệ thống trong ngưỡng `SLO`, trong trần `budget`, và xử lý sự cố khi bị bơm vào.
- Chủ động tìm vấn đề, sắp ưu tiên theo tác động business, rồi triển khai cải tiến.
- Ghi lại quyết định có ký tên, có lý do, có đánh đổi, có rollback plan.
- Báo cáo được trạng thái service theo ngôn ngữ business + kỹ thuật.

## 3. Timeline 3 tuần

### Tuần 1: Tiếp quản, dựng baseline, chốt backlog ưu tiên

Phải làm:

- Đọc kỹ `RULES.md`, `GETTING_STARTED.md`, toàn bộ `onboarding/`.
- Build image từ source, push lên `ECR` của TF, deploy trên cluster của TF.
- Bật observability và verify hệ thống đã sống.
- Hiểu kiến trúc, luồng critical, SLO, budget, lịch sử sự cố.
- Tự đánh giá hiện trạng và tạo **backlog ưu tiên**.
- Chuẩn bị và đi **pitch cuối tuần 1** để bảo vệ backlog.

Đầu ra quan trọng:

- Hệ thống chạy được trên môi trường TF.
- Danh sách ưu tiên top vấn đề/cải tiến.
- Pitch giải thích vì sao làm A trước B, và vì sao chưa làm các việc còn lại.

### Tuần 2-3: Vận hành thật và cải tiến dưới ràng buộc

Song song 3 luồng việc:

- Làm backlog đã pitch.
- Xử lý **directive bắt buộc** nếu BTC thả vào `mandates/`.
- Ứng phó **incident** do BTC bơm trong lúc vận hành.

Phải duy trì:

- On-call luân phiên.
- Weekly Ops Review.
- Theo dõi SLO, error budget, chi phí, tình trạng sự cố.
- Ghi decision log / ADR / postmortem đầy đủ.

### Kết thúc kỳ

Phải có:

- `Service Health Readout`: đã làm gì, đánh đổi gì, trạng thái hệ thống ra sao, bước tiếp theo là gì.

## 4. Những requirements cốt lõi CDO-02 cần làm

### 4.1. Yêu cầu bắt buộc về triển khai

- Tự build từ source tổ chức cấp.
- Tự push app images lên `ECR` của TF.
- Tự deploy trên account/cluster của TF.
- Khi deploy phải luôn kèm `deploy/values-flagd-sync.yaml`.

### 4.2. Yêu cầu bắt buộc về vận hành

- Phải giữ hệ thống trong ràng buộc `SLO` và `budget`.
- Phải có observability đủ để đo, cảnh báo, điều tra.
- Phải trực on-call và xử lý incident thật.
- Phải có weekly reporting theo kiểu Ops Review.

### 4.3. Yêu cầu bắt buộc về quản trị thay đổi

- Mọi quyết định lớn cần `ADR` hoặc decision log có ký tên.
- Mọi incident cần postmortem / COE có ký tên.
- Directive từ BTC phải có bằng chứng hoàn thành + rollback plan.

### 4.4. Yêu cầu bắt buộc về cách ưu tiên

- Ưu tiên theo `risk x business impact`, không ưu tiên theo cảm giác.
- Không cần làm hết mọi thứ; thứ được chấm là **chọn đúng việc đáng làm**.
- Checkout là luồng revenue-critical nên gần như luôn là vùng cần bảo vệ trước.

## 5. Các trụ CDO mà nhóm phải gánh

Theo luật chơi, CDO xoay quanh 5 trụ:

- `Security`
- `Reliability`
- `Performance Efficiency`
- `Cost Optimization`
- `Auditability`

Với `TF3` có 2 nhóm CDO, tài liệu nói:

- 2 nhóm sẽ chia nhau `4 trụ core`: Security, Reliability, Performance Efficiency, Cost Optimization.
- `Auditability` là phần dùng chung, luân phiên cầm chính theo tuần.

Lưu ý:

- Tài liệu **không chỉ rõ** ngay `CDO-02` được gán trụ nào.
- Nhóm nên chốt sớm với `CDO01` trong TF3: ai ownership trụ nào, ai cầm Auditability tuần nào.

## 6. Các SLO và ràng buộc business cần nhớ

### SLO chính

- Browse/search: success rate `>= 99.5%`
- Storefront p95 latency: `< 1s`
- Cart success rate: `>= 99.5%`
- Checkout success rate: `>= 99.0%`
- AI review summary: best-effort, nhưng **không được hiển thị nội dung sai lệch cho khách**

### Error budget

- Checkout có `1%` error budget trong cửa sổ đo.
- Nếu cháy budget thì phải giảm thay đổi rủi ro, ưu tiên ổn định hệ thống trước.

### Budget

- Trần ngân sách: khoảng `$300/tuần/TF`.
- Các quyết định tốn tiền lớn phải giải thích bằng lợi ích rõ ràng.

## 7. Những gì phải lưu ý rất kỹ

### 7.1. Điều kiện dễ bị loại

- Không được gỡ, vô hiệu hóa, đổi hướng `flagd` hoặc các hook đọc flag.
- Không được can thiệp cơ chế BTC dùng để bơm incident.
- Không được sửa kiểu "tắt nguồn gây lỗi" để né sự cố do BTC tạo.

Hiểu đúng:

- Nếu hệ thống có cấu hình kém thật thì sửa tận gốc.
- Nếu incident do BTC bơm, phải tăng khả năng chịu lỗi bằng `fallback`, `retry`, `containment`, rollout an toàn, quan sát tốt hơn.

### 7.2. Những vùng rủi ro đã lộ từ tài liệu

- `Checkout` từng fail giờ cao điểm do cạn kết nối DB.
- `Cart` từng mất state khi pod/node bị reschedule.
- Deploy từng làm lỗi payment vì thiếu readiness gating.

=> Điểm chung: hệ thống đang yếu ở `reliability dưới áp lực`.

### 7.3. Những lỗi thao tác dễ dính

- Deploy xong quên ghép lại `values-flagd-sync.yaml`.
- Chỉ nhìn pod `Running` mà chưa verify flow end-to-end.
- Không dựng dashboard/SLO sớm nên đến lúc incident không biết đo gì.
- Tăng tài nguyên quá tay rồi vượt budget.
- Làm thay đổi lớn mà không có ADR, rollback plan, hoặc người chịu trách nhiệm rõ ràng.

## 8. Gợi ý backlog rất hợp lý cho CDO-02

Nếu cần một hướng làm an toàn và dễ bảo vệ trong pitch, mình nghĩ nhóm nên xoay quanh các cụm sau:

### Ưu tiên 1: Reliability cho luồng checkout

- Rà replicas, readiness/liveness/startup probes cho các service critical.
- Kiểm tra rollout strategy để tránh traffic vào pod chưa sẵn sàng.
- Thiết kế timeout/retry/fallback có kiểm soát cho dependency chính.
- Dựng dashboard riêng cho checkout success rate, latency, error rate.

Lý do:

- Checkout là luồng ra tiền.
- Incident history đã chỉ ra đây là vùng đau thật.
- Chi phí thường thấp hơn so với các migration hạ tầng lớn.

### Ưu tiên 2: Quan sát và cảnh báo

- Dựng dashboard SLO, error budget, service health.
- Tạo alert cho checkout, cart, DB connection saturation, pod restart, readiness fail.
- Chuẩn hóa cách truy vết: metrics, logs, traces theo luồng.

Lý do:

- Không đo được thì không vận hành được.
- Đây là nền để xử lý incident và bảo vệ mọi quyết định.

### Ưu tiên 3: Cart durability / SPOF review

- Rà xem cart/valkey đang là single point of failure ở đâu.
- Làm rõ chấp nhận rủi ro hiện tại hay cần tăng độ bền.
- Nếu chưa đủ thời gian để làm HA đầy đủ, ít nhất phải có phương án containment và diễn giải rõ trong ADR.

### Ưu tiên 4: Cost guardrail

- Dựng AWS Budget + Cost Anomaly Detection sớm.
- Theo dõi chi phí node, observability, storage.
- Chỉ scale khi có số liệu chứng minh cần thiết.

### Ưu tiên 5: Auditability

- Mẫu hóa ADR, decision log, incident log, postmortem.
- Gắn rõ owner, thời điểm, quyết định, lý do, rollback, ảnh hưởng.

## 9. Gợi ý chiến lược pitch cho CDO-02

Khi pitch cuối tuần 1, nên nói theo logic này:

1. Hệ thống đã chạy baseline.
2. Luồng kiếm tiền là `checkout`, nên nhóm ưu tiên bảo vệ reliability trước.
3. Incident history cho thấy các lỗi trước đây đều xoay quanh quá tải, readiness, SPOF.
4. Budget chỉ khoảng `$300/tuần`, nên ưu tiên các cải tiến rẻ nhưng impact cao trước.
5. Các thay đổi lớn như managed DB / Multi-AZ chỉ làm nếu chứng minh được ROI và vẫn giữ budget.

Một backlog pitch tương đối dễ bảo vệ:

1. Dashboard + alert SLO cho checkout/cart.
2. Probe/rollout/readiness hardening cho service critical.
3. Review SPOF của cart + dependency chain.
4. Cost guardrail và theo dõi anomaly.
5. Sau đó mới cân nhắc các thay đổi tốn tiền hơn.

## 10. Kế hoạch thực dụng mình gợi ý cho tuần đầu

### Ngày 1

- Đọc hết packet.
- Chốt ownership giữa `CDO01` và `CDO02`.
- Dựng baseline lên cluster.

### Ngày 2

- Verify end-to-end flow: browse, product detail, cart, checkout, AI review.
- Mở Grafana, Jaeger, logs để hiểu đường đi request.
- Lập danh sách rủi ro ban đầu.

### Ngày 3

- Rà chart/config: replicas, probes, resource requests/limits, rollout, secrets, values.
- So khớp với SLO, budget và incident history.

### Ngày 4

- Chốt top backlog.
- Ước lượng impact, cost, risk, rollback cho từng item.
- Viết sườn pitch + ADR skeleton.

### Ngày 5

- Rehearse pitch.
- Chuẩn bị sẵn câu trả lời cho PM, CFO, SRE.

## 11. Chốt ngắn cho CDO-02

Nếu rút gọn đề bài còn 1 câu:

> `CDO-02` không cần chứng minh mình làm được nhiều nhất, mà cần chứng minh mình **chọn đúng việc nhất**, giữ service sống khỏe nhất, và giải thích quyết định của mình chặt nhất.

## 12. File mình đã đọc để tổng hợp

- `phase3/README.md`
- `phase3/RULES.md`
- `phase3/GETTING_STARTED.md`
- `phase3/mandates/README.md`
- `phase3/onboarding/ARCHITECTURE.md`
- `phase3/onboarding/BUDGET.md`
- `phase3/onboarding/INCIDENT_HISTORY.md`
- `phase3/onboarding/PITCH_GUIDE.md`
- `phase3/onboarding/SLO.md`
- `phase3/techx-corp-chart/README.md`
- `phase3/techx-corp-platform/README.md`
