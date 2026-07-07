# Runbook dựng baseline cluster cho CDO-02

## 1. Mục tiêu

Runbook này ghi lại cách nhóm CDO-02 đã dựng baseline Phase 3 lên EKS trong lần chạy thật ngày `2026-07-07`, gồm:

- Tạo cluster EKS
- Tạo ECR và trỏ image về registry của team
- Deploy chart `techx-corp`
- Nối `flagd` về central source bằng token BTC/TF
- Hotfix riêng service `shipping`
- Verify storefront, observability và flow mua hàng có thể chạy từ đầu đến cuối

Runbook này ưu tiên tính thực chiến. Nếu lý thuyết và thực tế khác nhau, hãy làm theo phần "thực tế đã chạy".

## 1.1. Trang thai repo hien tai

Tinh den lan cap nhat gan nhat:

- `shipping` khong con dung runtime hotfix trong baseline mac dinh nua
- baseline dang dung image `shipping` chuan tu ECR cua team voi tag `1.0-shipping`
- `flagd-ui` da duoc bat lai de nhom co the port-forward va mo UI local khi can
- `deploy.ps1 -SkipBuild` da tu verify image ECR, cap nhat kubeconfig, va tu recover neu release Helm cu bi ket `pending-*`

Neu ban gap tai lieu cu noi rang baseline van phu thuoc `shipping hotfix`, hay uu tien thong tin trong muc nay va trong folder `infra/`.

## 2. Đường dẫn repo hiện tại

Repo Phase 3 đã được tách ra khỏi workspace cũ và đặt tại:

```powershell
cd D:\Xbrain\techx-phase3-cdo02
```

Không dùng lại các đường dẫn cũ kiểu `D:\Xbrain\Phase2\xbrain-learners\phase3`.

## 3. Hiện trạng đã xác nhận

- AWS account: `593777010472`
- Region: `us-east-1`
- Cluster: `techx-tf3`
- Kubernetes version: `1.30`
- Nodegroup: `ng-core`
- Node type: `t3.large`
- Số node hiện tại: `2`
- Namespace deploy app: `techx-tf3`
- Helm release: `techx-corp`
- ECR repo: `593777010472.dkr.ecr.us-east-1.amazonaws.com/techx-corp`

## 4. File/folder quan trọng

- `techx-corp-platform/`: source code sản phẩm
- `techx-corp-chart/`: Helm chart deploy lên Kubernetes
- `deploy/`: script build/push, values và hotfix files
- `eksctl-techx-tf3-cluster.yaml`: cấu hình cluster đã dùng thực tế

## 5. Điều kiện trước khi chạy

Cần có:

- AWS CLI đã gắn credentials đúng account TF
- `kubectl`
- `helm`
- `docker`
- `docker buildx`
- `eksctl`
- Git Bash hoặc `bash` để chạy shell script trong `deploy/`

Kiểm tra nhanh:

```powershell
aws sts get-caller-identity
kubectl config current-context
kubectl get nodes
helm version
docker version
docker buildx version
```

## 6. Biến môi trường mẫu

```powershell
$ACCOUNT_ID = "593777010472"
$REGION = "us-east-1"
$CLUSTER_NAME = "techx-tf3"
$NAMESPACE = "techx-tf3"
$ECR_REPO = "techx-corp"
$ECR_REGISTRY = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
$IMAGE_NAME = "$ECR_REGISTRY/$ECR_REPO"
```

## 7. Tạo cluster EKS

### 7.1. Cấu hình đã dùng

File:

- [eksctl-techx-tf3-cluster.yaml](D:\Xbrain\techx-phase3-cdo02\eksctl-techx-tf3-cluster.yaml)

Điểm cần giữ nguyên:

- `autoModeConfig.enabled: false`
- `managedNodeGroups[].amiFamily: AmazonLinux2023`
- `managedNodeGroups[].instanceType: t3.large`
- `desiredCapacity: 2`

### 7.2. Lệnh tạo cluster

```powershell
eksctl create cluster -f .\eksctl-techx-tf3-cluster.yaml
```

### 7.3. Trường hợp `eksctl create cluster` bị ngắt giữa chừng

Lần chạy thật đã gặp trường hợp control plane lên xong nhưng lệnh bị ngắt. Cách recover an toàn:

```powershell
aws eks update-kubeconfig --name techx-tf3 --region us-east-1
eksctl utils associate-iam-oidc-provider --cluster techx-tf3 --region us-east-1 --approve
eksctl create nodegroup -f .\eksctl-techx-tf3-cluster.yaml
```

Sau đó kiểm tra:

```powershell
kubectl get nodes -o wide
```

## 8. Tạo ECR và login

```powershell
aws ecr create-repository --repository-name $ECR_REPO --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
```

Nếu repo đã tồn tại thì bỏ qua lỗi create-repository.

## 9. Trỏ image về ECR của team

Sửa file:

- [techx-corp-platform/.env.override](D:\Xbrain\techx-phase3-cdo02\techx-corp-platform\.env.override)

Giá trị đã dùng:

```env
IMAGE_NAME=593777010472.dkr.ecr.us-east-1.amazonaws.com/techx-corp
IMAGE_VERSION=1.0
DEMO_VERSION=1.0
```

## 10. Build và push image

Script hiện tại:

- [deploy/build-push-images.sh](D:\Xbrain\techx-phase3-cdo02\deploy\build-push-images.sh)

Lệnh:

```powershell
bash ./deploy/build-push-images.sh
```

Script này đã được sửa để:

- Chỉ build/push app images
- Tránh push các image observability public như `opensearch`
- Sử dụng `docker buildx bake`

### Lưu ý thực tế

- Trong lần chạy thật, build lại đầy đủ từ source bị chậm/timeout khi resolve metadata từ public registries.
- Vì vậy baseline live đã dùng chart + image seed sẵn có, sau đó hotfix riêng `shipping`.
- Về dài hạn, team nên build lại đầy đủ image `linux/amd64` lên ECR để bỏ hotfix tạm thời.

## 11. Chuẩn bị Helm dependencies

```powershell
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add opensearch https://opensearch-project.github.io/helm-charts
helm dependency build .\techx-corp-chart
```

## 12. Cấu hình `flagd` sync

File:

- [deploy/values-flagd-sync.yaml](D:\Xbrain\techx-phase3-cdo02\deploy\values-flagd-sync.yaml)

Bắt buộc phải có token sync thật do BTC/TF cấp. Mỗi lần `helm upgrade` sau này đều phải nhớ kèm file này.

## 13. Deploy baseline bằng Helm

Lệnh baseline đã dùng:

```powershell
helm upgrade --install techx-corp .\techx-corp-chart `
  -n $NAMESPACE --create-namespace `
  --set default.image.repository=$IMAGE_NAME `
  -f .\deploy\values-flagd-sync.yaml
```

Nếu cần LLM thật thì mới ghép thêm:

```powershell
-f .\deploy\values-aio-llm.yaml
```

## 14. Verify pod sau deploy

```powershell
kubectl -n $NAMESPACE get pods -o wide
```

Mục tiêu tối thiểu:

- Tất cả pod `Running`
- `frontend-proxy`, `frontend`, `checkout`, `cart`, `quote`, `product-catalog`, `product-reviews`, `llm`, `grafana`, `jaeger`, `prometheus` đều sẵn sàng

## 15. Vấn đề thực tế đã gặp với `shipping`

### 15.1. Triệu chứng

Service `shipping` bị `CrashLoopBackOff`.

Log lỗi chính:

```text
exec ./shipping: exec format error
```

### 15.2. Nguyên nhân

Image seed cho `shipping` không khớp kiến trúc node EKS `amd64`.

### 15.3. Cách xử lý đã dùng thành công

Team đã hotfix trực tiếp deployment bằng Python thay thế tạm thời, dùng 2 file sau:

- [deploy/shipping-hotfix-configmap.yaml](D:\Xbrain\techx-phase3-cdo02\deploy\shipping-hotfix-configmap.yaml)
- [deploy/shipping-hotfix-deployment-patch.yaml](D:\Xbrain\techx-phase3-cdo02\deploy\shipping-hotfix-deployment-patch.yaml)

Lệnh:

```powershell
kubectl apply -f .\deploy\shipping-hotfix-configmap.yaml
kubectl -n $NAMESPACE patch deployment shipping --type strategic --patch-file .\deploy\shipping-hotfix-deployment-patch.yaml
kubectl -n $NAMESPACE rollout status deployment/shipping --timeout=180s
```

Kiểm tra:

```powershell
kubectl -n $NAMESPACE get pods | findstr shipping
kubectl -n $NAMESPACE logs deploy/shipping --tail=100
```

Sau hotfix, log đã có:

- `shipping_quote_generated`
- `shipping_tracking_created`

Điều này xác nhận `shipping` đã nối được với `quote` và được `checkout` gọi tới.

### 15.4. Kết luận kỹ thuật

Hotfix này giúp baseline và end-to-end flow hoạt động để team tiếp tục Phase 3. Đây chưa phải cách kết thúc lý tưởng. Cách sạch hơn về sau:

1. Build lại `shipping` từ source cho `linux/amd64`
2. Push lên ECR team
3. Đưa override vào chart thay vì patch runtime

## 16. Port-forward storefront và observability

```powershell
kubectl -n $NAMESPACE port-forward svc/frontend-proxy 8080:8080
```

Kiểm tra:

- `http://localhost:8080`
- `http://localhost:8080/grafana/`
- `http://localhost:8080/jaeger/ui/`
- `http://localhost:8080/loadgen/`

Trong lần verify thật, các URL trên đã trả `200`.

## 17. Verify end-to-end bằng API

Lệnh PowerShell đã chạy thành công:

```powershell
$base='http://localhost:8080'
$userId='cdo02-user'
$address = @{
  streetAddress='1600 Amphitheatre Parkway'
  city='Mountain View'
  state='CA'
  country='United States'
  zipCode='94043'
}

try {
  Invoke-RestMethod -Uri "$base/api/cart" -Method DELETE -ContentType 'application/json' -Body (@{ userId=$userId } | ConvertTo-Json) | Out-Null
} catch {}

$productList = Invoke-RestMethod -Uri "$base/api/products?currencyCode=USD" -Method GET
$productA = $productList[0]
$productB = $productList[-1]

Invoke-RestMethod -Uri "$base/api/cart" -Method POST -ContentType 'application/json' -Body (@{ userId=$userId; item=@{ productId=$productA.id; quantity=1 } } | ConvertTo-Json -Depth 10) | Out-Null
Invoke-RestMethod -Uri "$base/api/cart" -Method POST -ContentType 'application/json' -Body (@{ userId=$userId; item=@{ productId=$productB.id; quantity=1 } } | ConvertTo-Json -Depth 10) | Out-Null

$cart = Invoke-RestMethod -Uri "$base/api/cart?sessionId=$userId&currencyCode=USD" -Method GET
$itemListJson = [System.Uri]::EscapeDataString(($cart.items | ConvertTo-Json -Compress -Depth 10))
$addressJson = [System.Uri]::EscapeDataString(($address | ConvertTo-Json -Compress -Depth 10))
$shipping = Invoke-RestMethod -Uri ("$base/api/shipping?itemList=$itemListJson&address=$addressJson&currencyCode=USD") -Method GET
$productDetail = Invoke-RestMethod -Uri ("$base/api/products/{0}?currencyCode=USD" -f $productA.id) -Method GET
$reviews = Invoke-RestMethod -Uri ("$base/api/product-reviews/{0}" -f $productA.id) -Method GET
$aiReview = Invoke-RestMethod -Uri ("$base/api/product-ask-ai-assistant/{0}" -f $productA.id) -Method POST -ContentType 'application/json' -Body (@{ question='What is one key feature of this product?' } | ConvertTo-Json)
$checkout = Invoke-RestMethod -Uri "$base/api/checkout?currencyCode=USD" -Method POST -ContentType 'application/json' -Body (@{
  userId=$userId
  userCurrency='USD'
  email='cdo02@example.com'
  address=$address
  creditCard=@{
    creditCardNumber='4432-8015-6152-0454'
    creditCardCvv=672
    creditCardExpirationYear=2030
    creditCardExpirationMonth=1
  }
} | ConvertTo-Json -Depth 10)

[ordered]@{
  product_count = $productList.Count
  cart_items = $cart.items.Count
  shipping_currency = $shipping.currencyCode
  product_detail_name = $productDetail.name
  review_count = @($reviews).Count
  ai_review = $aiReview
  order_id = $checkout.orderId
  shipping_tracking = $checkout.shippingTrackingId
  ordered_items = $checkout.items.Count
} | ConvertTo-Json -Depth 10
```

Kết quả thật đã xác nhận:

- Browse sản phẩm: OK
- Product detail: OK
- Cart: OK
- Shipping quote: OK
- Checkout: OK
- AI review: có response, nhưng hiện tại là fallback `Sorry, I'm not able to answer that question.`

## 18. Verify `flagd`

Kiểm tra pod:

```powershell
kubectl -n $NAMESPACE get pods | findstr flagd
```

Kiểm tra deployment nếu cần:

```powershell
kubectl -n $NAMESPACE get deploy flagd -o yaml
```

Mục tiêu:

- `flagd` phải `Running`
- Deployment đã ăn `values-flagd-sync.yaml`
- Không quay về local toggle flow

## 19. Checklist chốt baseline

- [ ] `aws sts get-caller-identity` đúng account
- [ ] `kubectl get nodes` ra `2` node `Ready`
- [ ] ECR repo của team tồn tại
- [ ] `.env.override` trỏ đúng ECR
- [ ] `helm dependency build` thành công
- [ ] Deploy chart thành công
- [ ] `flagd` đã sync bằng values file có token
- [ ] Tất cả pod `Running`
- [ ] `shipping` đã được hotfix và rollout thành công
- [ ] Storefront trả `200`
- [ ] Grafana trả `200`
- [ ] Jaeger trả `200`
- [ ] Load generator trả `200`
- [ ] Browse/product detail/cart/checkout chạy được

## 20. Lỗi hay gặp và cách xử lý

### 20.1. Windows không nhận `eksctl`

Mở PowerShell mới hoặc gọi full path tới `eksctl.exe`.

### 20.2. `helm upgrade` bị lock/pending

Lần chạy thật đã gặp tình huống upgrade bị `pending-upgrade`/`pending-rollback`. Nếu mất nhiều thời gian để gỡ lock, tạm thời có thể:

1. Dừng deploy baseline ở revision ổn định
2. Patch riêng deployment lỗi bằng `kubectl`
3. Sau đó dọn dẹp Helm history cẩn thận

Không reset bừa bãi release nếu chưa biết rõ impact.

### 20.3. `shipping` bị `exec format error`

Áp dụng ngay hotfix ConfigMap + deployment patch ở Mục 15.

### 20.4. `product detail` hoặc `shipping` test tay lỗi do URL

Khi gọi PowerShell, cần dùng chuỗi có `-f` hoặc string hoàn chỉnh. Lần test lỗi trước đây do gọi URL sai định dạng query string.

### 20.5. Build image timeout registry

Nếu `docker buildx` timeout tới Docker Hub/GCR/MCR:

- Xác nhận network ra internet
- Retry bằng Git Bash
- Ưu tiên build lại từng service quan trọng
- Chốt tạm baseline bằng hotfix runtime nếu cần deadline

## 21. Recommendation cho lần dựng tiếp theo

1. Giữ nguyên cluster scaffold và path repo hiện tại.
2. Build lại riêng service `shipping` thành image `linux/amd64` trong ECR team để bỏ hotfix tạm.
3. Sau khi `shipping` ổn định, mới tính tới tối ưu chart và tách observability nếu cần.
4. Mọi tài liệu nghiệm thu/bàn giao nên đưa vào file verify thực tế, không đưa vào giả định ban đầu.
