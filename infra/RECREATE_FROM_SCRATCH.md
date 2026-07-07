# Recreate From Scratch

## 1. Mục tiêu

File này hướng dẫn dựng lại toàn bộ môi trường sau khi bạn đã chạy:

```powershell
terraform destroy -auto-approve -var-file .\terraform.tfvars
```

Ta sẽ chia làm 2 tình huống:

1. ECR vẫn còn image
2. ECR đã bị xóa hoặc repo ECR không còn image cần thiết

## 2. Hiểu đúng về `terraform destroy`

Sau khi destroy, những thứ thường bị gỡ là:

- VPC
- EKS cluster
- node group
- namespace
- Helm release
- ECR repository `techx-corp` nếu Terraform destroy đi hết được

Điều quan trọng là:

- nếu ECR vẫn còn image, `terraform destroy` có thể fail ở bước xóa ECR
- nếu ECR bị xóa hẳn, lần dựng lại sẽ phải tạo lại repo và push lại image

Vì vậy, trước khi dựng lại, nên kiểm tra xem repo ECR và image còn hay không.

## 3. Điều kiện cần trước khi dựng lại

Máy local cần có:

- `terraform`
- `aws`
- `kubectl`

Và cần đảm bảo:

- AWS CLI đang trỏ đúng account
- file `infra/terraform.tfvars` còn tồn tại
- `flagd_sync_token` trong `terraform.tfvars` còn đúng

Kiểm tra nhanh:

```powershell
aws sts get-caller-identity
```

Di chuyển vào đúng folder:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
```

## 4. Kiểm tra ECR còn hay mất

Kiểm tra repo ECR:

```powershell
aws ecr describe-repositories --repository-names techx-corp --region us-east-1
```

Nếu repo còn, kiểm tra image tag:

```powershell
aws ecr list-images --repository-name techx-corp --region us-east-1 --query "imageIds[?imageTag!=null].imageTag" --output table
```

Baseline hiện tại cần tối thiểu các tag:

- `1.0-accounting`
- `1.0-ad`
- `1.0-cart`
- `1.0-checkout`
- `1.0-currency`
- `1.0-email`
- `1.0-flagd-ui`
- `1.0-fraud-detection`
- `1.0-frontend`
- `1.0-frontend-proxy`
- `1.0-image-provider`
- `1.0-kafka`
- `1.0-llm`
- `1.0-load-generator`
- `1.0-payment`
- `1.0-product-catalog`
- `1.0-product-reviews`
- `1.0-quote`
- `1.0-recommendation`
- `1.0-shipping`

## 5. Trường hợp A: ECR còn đủ image

Đây là trường hợp dễ nhất.

### Bước 1: kiểm tra lại `terraform.tfvars`

Giữ các giá trị baseline:

```hcl
default_image_tag          = "1.0"
shipping_image_tag         = "1.0-shipping"
bootstrap_from_seed_images = false
enable_shipping_hotfix     = false
deploy_release             = false
```

### Bước 2: chạy deploy

```powershell
.\deploy.ps1 -SkipBuild
```

Script sẽ tự làm:

1. `terraform init`
2. tạo lại VPC, EKS, node group, ECR nếu cần
3. tạo `.env.override`
4. `aws eks update-kubeconfig`
5. verify image trong ECR
6. deploy Helm release
7. chờ rollout workload chính

### Bước 3: kiểm tra sau deploy

```powershell
kubectl -n techx-tf3 get pods
```

Nếu cần kiểm tra frontend:

```powershell
kubectl -n techx-tf3 port-forward svc/frontend-proxy 18080:8080
```

Mở:

- `http://127.0.0.1:18080`

## 6. Trường hợp B: ECR mất image hoặc repo ECR đã bị xóa

Đây là trường hợp phải build lại image trước.

### Bước 1: dựng lại cloud nền tảng trước

Làm bước này để Terraform tạo lại EKS và ECR repository:

```powershell
terraform init
terraform apply -auto-approve -var-file .\terraform.tfvars -var "deploy_release=false"
```

### Bước 2: build lại image lên ECR

Hướng khuyến nghị là GitHub Actions.

Chạy workflow:

- `Build Platform To ECR`

Input khuyến nghị:

- `aws_region = us-east-1`
- `ecr_repository = techx-corp`
- `base_image_tag = 1.0`
- `push_sha_tags = true`

Chờ workflow push đủ bộ image `1.0-*` lên ECR, bao gồm cả `1.0-flagd-ui`.

### Bước 3: deploy release

Sau khi image đã có đủ:

```powershell
.\deploy.ps1 -SkipBuild
```

### Bước 4: kiểm tra sau deploy

```powershell
kubectl -n techx-tf3 get pods
```

Nếu cần kiểm tra frontend:

```powershell
kubectl -n techx-tf3 port-forward svc/frontend-proxy 18080:8080
```

## 7. Nếu muốn local build thay cho GitHub Actions

Chỉ dùng khi máy local đủ khỏe và Docker ổn định.

Khi đó có thể chạy:

```powershell
.\deploy.ps1
```

Không dùng `-SkipBuild`.

Script sẽ tự:

1. dựng EKS + ECR
2. login ECR
3. build/push image từ local
4. deploy Helm release

Nhưng đây không phải hướng khuyến nghị cho máy yếu.

## 8. Flow ngắn gọn nên nhớ

### Nếu ECR còn image

Chỉ cần:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
.\deploy.ps1 -SkipBuild
```

### Nếu ECR không còn image

Làm theo thứ tự:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
terraform init
terraform apply -auto-approve -var-file .\terraform.tfvars -var "deploy_release=false"
```

Sau đó chạy GitHub Actions `Build Platform To ECR`, rồi:

```powershell
.\deploy.ps1 -SkipBuild
```

## 9. Lưu ý quan trọng

1. `deploy.ps1 -SkipBuild` không tự build image.
2. `deploy.ps1 -SkipBuild` chỉ deploy được nếu image đã có trong ECR.
3. Nếu `terraform destroy` xóa luôn ECR, bạn bắt buộc phải push lại image trước khi deploy app.
4. Baseline release hiện bật `flagd-ui` sidecar để nhóm có thể vào UI local trong cluster khi cần quan sát hoặc double-check trước khi BTC thao tác với flag trung tâm.
5. Nếu `terraform destroy` fail ở ECR vì repo không rỗng, cần xóa image trong ECR trước rồi destroy lại.

## 10. Câu trả lời ngắn nhất

Sau khi destroy:

- nếu ECR còn image: chạy `.\deploy.ps1 -SkipBuild` là đủ
- nếu ECR mất image: phải build lại image trước, rồi mới chạy `.\deploy.ps1 -SkipBuild`
