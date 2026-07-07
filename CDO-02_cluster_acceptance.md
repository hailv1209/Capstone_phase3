# CDO-02 Nghiệm Thu Baseline Cluster

## 1. Mục đích

File này dùng để nghiệm thu sau khi baseline đã được đẩy lên cluster. Các bước dưới đây bám sát vào tình hình live của CDO-02 ngày `2026-07-07`.

## 2. Port-forward cần mở trước

Mở storefront + observability:

```powershell
kubectl -n techx-tf3 port-forward svc/frontend-proxy 8080:8080
```

Nếu muốn mở log streaming riêng:

```powershell
kubectl -n techx-tf3 logs deploy/frontend -f
kubectl -n techx-tf3 logs deploy/checkout -f
kubectl -n techx-tf3 logs deploy/shipping -f
kubectl -n techx-tf3 logs deploy/product-catalog -f
```

## 3. Verify end-to-end flow

### 3.1. Browse

Mở:

- `http://localhost:8080`

Cần thấy:

- Trang chủ storefront hiện lên
- Danh sách sản phẩm load được

### 3.2. Product detail

Tác vụ:

1. Click vào 1 product card
2. Vào trang chi tiết sản phẩm

Cần thấy:

- Tên sản phẩm
- Thông tin chi tiết
- Khu vực review
- Khu vực AI review/AI assistant

### 3.3. Cart

Tác vụ:

1. Thêm sản phẩm thứ nhất vào giỏ
2. Quay lại home
3. Thêm thêm sản phẩm thứ hai vào giỏ
4. Mở cart

Cần thấy:

- Số lượng item trong cart tăng lên
- Cart page load được

### 3.4. Checkout

Tác vụ:

1. Vào cart
2. Bấm place order

Cần thấy:

- Checkout page load được
- Có order id
- Có shipping tracking id

### 3.5. AI review

Tác vụ:

1. Vào product detail
2. Gọi AI assistant hoặc xem AI review summary

Cần thấy:

- API có response

Lưu ý hiện tại:

- Response đã verify là có trả về, nhưng có thể đang là fallback `Sorry, I'm not able to answer that question.`

## 4. Verify nhanh bằng PowerShell

Nếu muốn check nhanh bằng API thay vì click tay:

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

## 5. Mở Grafana, Jaeger, logs để hiểu đường đi request

### Grafana

Mở:

- `http://localhost:8080/grafana/`

Cần xem:

- Dashboard tổng quan
- Metric của `frontend`, `checkout`, `shipping`
- Spike latency khi thực hiện checkout

### Jaeger

Mở:

- `http://localhost:8080/jaeger/ui/`

Cần xem:

- Trace của request browse
- Trace của request product detail
- Trace của request checkout

Ưu tiên tìm luồng:

- `frontend` -> `product-catalog`
- `frontend` -> `cart`
- `frontend` -> `checkout` -> `payment` + `shipping` + `email`

### Logs

Lệnh:

```powershell
kubectl -n techx-tf3 logs deploy/frontend --tail=200
kubectl -n techx-tf3 logs deploy/checkout --tail=200
kubectl -n techx-tf3 logs deploy/shipping --tail=200
kubectl -n techx-tf3 logs deploy/product-catalog --tail=200
```

Cần đối chiếu:

- Khi click browse có log từ frontend/product-catalog
- Khi checkout có log từ checkout/shipping
- `shipping` có `shipping_quote_generated` và `shipping_tracking_created`

## 6. Danh sách rủi ro ban đầu

1. `shipping` đang là hotfix runtime, chưa phải image build chính thức từ source.
2. AI review có response nhưng đang fallback, chưa đạt mức chất lượng cuối.
3. Build image từ source có thể gặp timeout tới Docker Hub/GCR/MCR.
4. Helm release đã từng gặp pending/lock, cần kỷ luật hơn khi rollback/upgrade.
5. Chưa có bộ Terraform hoàn chỉnh để one-command recreate toàn bộ môi trường, nên cần bộ `infra/` mới để giảm manual drift.

## 7. Điều kiện để ký nghiệm thu baseline

Có thể xem là đạt baseline nếu:

- `kubectl -n techx-tf3 get pods` ra toàn bộ pod `Running`
- Storefront/Grafana/Jaeger/load generator mở được
- Browse, product detail, cart, checkout chạy được
- `shipping` đã không còn `CrashLoopBackOff`
- Có bằng chứng trace/log có request đi qua hệ thống
