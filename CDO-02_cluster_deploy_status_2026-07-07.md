# CDO-02 Cluster Deploy Status - 2026-07-07

## 1. Tổng quan

Baseline Phase 3 đã được dựng lên EKS và đã verify được flow chính. Blocker lớn nhất ban đầu là service `shipping` đã được xử lý bằng hotfix runtime, giúp hệ thống có thể browse, thêm giỏ, tính shipping và checkout thành công.

## 2. Thông tin live đã xác nhận

- AWS account: `593777010472`
- Region: `us-east-1`
- Cluster: `techx-tf3`
- Kubernetes version: `1.30`
- Nodegroup: `ng-core`
- Node type: `t3.large`
- Namespace: `techx-tf3`
- Helm release: `techx-corp`
- ECR repo: `593777010472.dkr.ecr.us-east-1.amazonaws.com/techx-corp`

## 3. Những gì đã hoàn thành

- Tách repo Phase 3 ra thành workspace riêng tại `D:\Xbrain\techx-phase3-cdo02`
- Tạo và recover cluster `techx-tf3`
- Cập nhật kubeconfig và xác nhận `2` node `Ready`
- Tạo ECR repo của team
- Cập nhật `techx-corp-platform/.env.override`
- Cập nhật `deploy/values-flagd-sync.yaml` bằng token đã cung cấp
- Deploy Helm chart `techx-corp`
- Hotfix service `shipping`
- Verify storefront và các endpoint observability qua `port-forward`
- Verify end-to-end flow bằng API

## 4. Trạng thái workload hiện tại

Khi chốt status này:

- Toàn bộ pod trong namespace `techx-tf3` đang `Running`
- `shipping` đã `Running` sau hotfix
- `frontend-proxy`, `grafana`, `jaeger`, `load-generator` đều trả `200` qua `http://localhost:8080/...`

## 5. Vấn đề `shipping` và cách xử lý

### Triệu chứng cũ

- Pod `shipping` bị `CrashLoopBackOff`
- Log lỗi: `exec ./shipping: exec format error`

### Cách xử lý đã áp dụng

- Tạo [deploy/shipping-hotfix-configmap.yaml](D:\Xbrain\techx-phase3-cdo02\deploy\shipping-hotfix-configmap.yaml)
- Tạo [deploy/shipping-hotfix-deployment-patch.yaml](D:\Xbrain\techx-phase3-cdo02\deploy\shipping-hotfix-deployment-patch.yaml)
- Patch deployment `shipping` để chạy `python:3.12-slim-bookworm`
- Mount file `shipping.py` từ ConfigMap
- Thêm readiness/liveness probe

### Kết quả

Log `shipping` đã có:

- `shipping_quote_generated`
- `shipping_tracking_created`

Điều này xác nhận service đã phục vụ được `get-quote` và `ship-order`.

## 6. Kết quả verify end-to-end

Đã verify thành công:

- Browse danh sách sản phẩm
- Mở product detail
- Thêm `2` sản phẩm vào cart
- Lấy shipping quote
- Checkout thành công
- Nhận `order_id`
- Nhận `shipping_tracking`

Kết quả AI review hiện tại:

- API có response
- Response đang là fallback: `Sorry, I'm not able to answer that question.`

Nói cách khác, đường đi AI có tồn tại nhưng chất lượng câu trả lời hiện tại chưa phải mục tiêu cuối.

## 7. Rủi ro còn lại

1. `shipping` đang là hotfix runtime, chưa phải image chính thức build từ source cho `linux/amd64`.
2. Build từ source vẫn có rủi ro timeout khi pull metadata/base image từ public registry.
3. AI review đang fallback, cần phân tích thêm nếu muốn nâng chất lượng output.
4. Helm release đã từng bị pending/lock trong quá trình sửa nóng; về sau cần dọn lại quy trình deploy cho sạch hơn.

## 8. Đánh giá hiện tại

Nếu mục tiêu là có baseline sống để nhóm CDO-02 tiếp tục làm cloud/devops và observability, trạng thái hiện tại đạt yêu cầu. Nếu mục tiêu là baseline "production-like" và sạch tuyệt đối, cần làm thêm ít nhất:

1. Rebuild `shipping` image chuẩn `amd64`
2. Đưa override vào chart thay vì patch runtime
3. Ổn định hóa quy trình build/push từ source
