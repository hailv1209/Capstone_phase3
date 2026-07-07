# Đề xuất chọn trụ cho CDO-02

## Kết luận ngắn

Mình đề xuất `CDO-02` chọn:

- `Reliability`
- `Performance Efficiency`

Và để `CDO01` nhận:

- `Security`
- `Cost Optimization`

`Auditability` thì cả hai nhóm cùng gánh, nhưng nên chia tuần cầm chính rõ ràng.

---

## 1. Vì sao CDO-02 nên chọn `Reliability + Performance Efficiency`

### 1.1. Đây là cặp trụ bám sát nhất vào “nỗi đau thật” của hệ thống

Từ tài liệu `phase3`, các sự cố lịch sử đều tập trung vào:

- checkout chậm/lỗi giờ cao điểm do cạn kết nối DB
- cart mất state khi pod/node bị reschedule
- deploy gây lỗi payment vì traffic vào pod chưa ready

Điểm chung của cả 3:

- đều là bài toán **độ tin cậy khi có áp lực**
- đều liên quan trực tiếp đến **khả năng chịu tải / scale / rollout / readiness / dependency health**

Nói cách khác:

- `Reliability` là trụ đánh trúng nguyên nhân business-critical nhất
- `Performance Efficiency` là trụ bổ trợ rất mạnh để giải quyết phần “dưới tải, dưới peak, dưới pressure”

### 1.2. Đây là cặp trụ dễ tạo impact thấy ngay trên SLO

Các SLO trong onboarding cho thấy:

- checkout success rate `>= 99.0%`
- cart success rate `>= 99.5%`
- browse/search `>= 99.5%`
- storefront p95 `< 1s`

Nếu nhóm bạn chọn `Reliability + Performance Efficiency`, bạn có thể tác động trực tiếp lên:

- success rate checkout
- latency storefront
- khả năng chịu incident
- hành vi under load

Đây là thứ hội đồng rất dễ thấy giá trị.

### 1.3. Đây là cặp trụ dễ bảo vệ trong pitch nhất

Vì bạn là nhóm thắng Phase 2 và được chọn trước, nên nên lấy cặp trụ:

- có impact business cao nhất
- có nhiều evidence nhất từ tài liệu
- có khả năng ra backlog rất rõ ràng ngay từ tuần 1

`Reliability + Performance Efficiency` thỏa cả 3.

Bạn có thể bảo vệ rất dễ:

> “Luồng checkout là luồng ra tiền. Incident history chỉ ra hệ thống yếu ở reliability dưới áp lực. Vì vậy nhóm chọn Reliability để bảo vệ SLO, và Performance Efficiency để xử lý đúng bản chất vấn đề khi traffic tăng, resource căng, dependency nghẽn.”

---

## 2. Vì sao chưa nên ưu tiên `Security` làm trụ pick đầu

Không phải `Security` không quan trọng. Nó quan trọng. Nhưng với riêng hệ thống này:

- tài liệu onboarding chưa đưa ra incident security nào nổi bật bằng checkout/cart/deploy
- pain hiện tại lộ rõ hơn ở runtime reliability và load behavior
- tuần 1 cần dựng backlog có thể bảo vệ rất nhanh bằng bằng chứng cụ thể

Nếu pick `Security` ngay từ đầu, nhóm vẫn làm được, nhưng sẽ khó hơn ở chỗ:

- khó chứng minh business impact tức thì bằng dữ liệu có sẵn
- dễ rơi vào hardening đúng nhưng “không phải vết đau lớn nhất lúc này”

`Security` hợp hơn để `CDO01` cầm như trụ còn lại, rồi phối hợp với bạn khi cần:

- service account
- least privilege
- secret handling
- image hygiene
- hardening pod/container

---

## 3. Vì sao chưa nên ưu tiên `Cost Optimization` làm trụ pick đầu

Budget đúng là có trần khoảng `$300/tuần/TF`, nhưng hiện trạng hệ thống cho thấy:

- nếu chưa giữ được checkout/cart ổn định thì tối ưu cost quá sớm sẽ dễ phản tác dụng
- nhiều thứ trong chart đang under-provisioned hoặc single-point-of-failure
- lúc này “tiết kiệm bằng cách cắt quá tay” dễ làm vỡ SLO

`Cost Optimization` nên có người ownership rõ, nhưng chưa nên là trụ pick đầu của nhóm thắng nếu mục tiêu là ăn điểm mạnh nhất.

Nên để `CDO01` cầm trụ này và phối hợp theo kiểu:

- bạn lo reliability/perf baseline
- họ lo guardrail cost, budget alert, anomaly, right-sizing có kiểm soát

Như vậy TF3 có thế cân bằng hơn.

---

## 4. So sánh nhanh các phương án chọn trụ

## Phương án A: `Reliability + Performance Efficiency`

### Điểm mạnh

- bám rất sát incident history
- tác động trực tiếp lên checkout/cart/storefront
- dễ ra backlog tuần 1
- dễ chứng minh ROI business
- hợp với đặc thù cloud/devops

### Điểm yếu

- nếu chỉ chăm reliability mà không phối hợp cost thì có nguy cơ scale quá tay

### Đánh giá

- Đây là **phương án tốt nhất**

## Phương án B: `Reliability + Security`

### Điểm mạnh

- rất “chuẩn DevOps”
- một trụ bảo vệ uptime, một trụ bảo vệ posture

### Điểm yếu

- kém ăn khớp hơn với incident history so với Performance Efficiency
- khó tạo quick win bằng evidence hơn

### Đánh giá

- Đây là **phương án dự phòng tốt**

## Phương án C: `Performance Efficiency + Cost Optimization`

### Điểm mạnh

- hợp bài toán right-size, autoscaling, budget

### Điểm yếu

- không đánh trúng vết đau reliability lớn nhất
- dễ bị hội đồng hỏi: “nếu service chưa ổn định thì sao ưu tiên cost/perf trước reliability?”

### Đánh giá

- Không nên là lựa chọn số 1

## Phương án D: `Security + Cost Optimization`

### Điểm mạnh

- hợp với governance/platform

### Điểm yếu

- xa luồng ra tiền và incident history nhất
- khó chứng minh impact hơn

### Đánh giá

- Không nên pick đầu với lợi thế winner

---

## 5. CDO-02 sẽ làm gì nếu chọn `Reliability + Performance Efficiency`

## 5.1. Backlog tuần 1 rất hợp lý

### Reliability

- rà `replica` cho các service critical
- rà `readiness/liveness/startup probes`
- rà rollout safety và deploy gating
- rà failure handling cho `checkout -> payment/shipping/catalog/cart`
- dựng alert cho:
  - checkout error rate
  - cart health
  - readiness fail
  - pod restart
  - dependency unavailable

### Performance Efficiency

- rà memory/CPU limit hiện tại trong chart
- rà điểm under-provisioned trong `values.yaml`
- đánh giá path nào dễ nghẽn khi peak
- dùng load generator để test hành vi dưới tải
- dựng dashboard:
  - checkout latency
  - storefront p95
  - Kafka lag
  - DB saturation
  - pod resource pressure

## 5.2. Những file repo nhóm bạn sẽ dùng nhiều nhất

- `phase3/techx-corp-chart/values.yaml`
- `phase3/deploy/values-observability.yaml`
- `phase3/deploy/values-app-stamp.yaml`
- `phase3/deploy/values-flagd-sync.yaml`
- `phase3/techx-corp-platform/src/checkout/main.go`
- `phase3/techx-corp-platform/src/cart/src/Program.cs`
- `phase3/techx-corp-platform/src/cart/src/services/HealthCheckService.cs`
- `phase3/techx-corp-platform/src/product-catalog/main.go`
- `phase3/techx-corp-platform/src/frontend-proxy/envoy.tmpl.yaml`
- `phase3/techx-corp-platform/src/otel-collector/otelcol-config.yml`
- `phase3/techx-corp-platform/src/prometheus/prometheus-config.yaml`
- `phase3/techx-corp-platform/src/flagd/demo.flagd.json`

## 5.3. Các kết quả dễ tạo điểm

- checkout path ổn định hơn khi dependency lỗi
- rollout an toàn hơn, giảm lỗi lúc deploy
- dashboard/alert rõ ràng
- có evidence test dưới tải
- biết trade-off giữa scale và budget

---

## 6. Cách chia việc với CDO01 nếu TF3 chốt theo đề xuất này

## CDO-02

- `Reliability`
- `Performance Efficiency`
- tuần 1 lead backlog cho checkout/cart/observability/load behavior

## CDO01

- `Security`
- `Cost Optimization`
- tuần 1 lead backlog cho:
  - budget guardrail
  - service account / secret / image / hardening review
  - cost anomaly / quota / right-size policy

## Auditability

Gợi ý chia:

- tuần 1: `CDO-02` cầm chính vì đang dựng baseline + backlog + ADR nhiều
- tuần 2: `CDO01` cầm chính
- tuần 3: chia theo incident / directive

---

## 7. Nếu nhóm bạn muốn phương án dự phòng

Nếu sau khi tự nhìn năng lực đội mà thấy:

- team mạnh hơn về IAM, policy, secret, hardening
- ít tự tin với load/perf tuning

thì phương án dự phòng nên là:

- `Reliability + Security`

Nhưng nếu hỏi phương án **mạnh nhất để pick trước** dựa trên đề bài và repo hiện tại, mình vẫn giữ đề xuất:

- `Reliability + Performance Efficiency`

---

## 8. Câu chốt để đem đi họp nội bộ

> Vì CDO-02 được pick trước và mục tiêu là chọn trụ tạo impact lớn nhất lên service health, nhóm nên lấy `Reliability + Performance Efficiency`. Đây là cặp trụ đánh trúng nhất vào incident history, SLO quan trọng nhất là checkout, và cũng là cặp dễ ra backlog, dễ làm evidence, dễ bảo vệ nhất trong pitch tuần 1.

## 9. Recommendation cuối cùng

### Chọn chính thức

- `Reliability`
- `Performance Efficiency`

### Định hướng phối hợp TF3

- `CDO-02`: Reliability + Performance Efficiency
- `CDO01`: Security + Cost Optimization
- cả hai nhóm cùng gánh `Auditability`
