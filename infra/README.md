# Infra cho CDO-02

## 1. Mục tiêu

Folder `infra/` cung cấp baseline để dựng lại môi trường Phase 3 trên AWS/EKS với ít thao tác tay nhất có thể.

Flow khuyến nghị hiện tại là:

1. Terraform dựng VPC, EKS, node group, ECR và file `.env.override`
2. GitHub Actions build toàn bộ service từ source rồi push lên ECR của team
3. Từ máy local chạy `.\deploy.ps1 -SkipBuild`
4. Terraform deploy Helm release lên cluster
5. Helm chart dùng image từ ECR của team cho toàn bộ app services

Đây là hướng vận hành ưu tiên cho nhóm vì:

- không phụ thuộc Docker local
- không phụ thuộc seed image upstream cho luồng chính
- dễ audit image/tag nào đang chạy
- phù hợp hơn khi code các service tiếp tục thay đổi

## 2. Thành phần đang được quản lý

- VPC
- EKS cluster
- Managed node group
- ECR repository `techx-corp`
- Sinh file `techx-corp-platform/.env.override`
- Namespace Kubernetes
- Helm release `techx-corp`
- Cấu hình `flagd` sync về central source
- Cờ bootstrap tạm từ seed image nếu cần
- Shipping hotfix fallback nếu cần bật lại

## 3. Các file chính

- `versions.tf`
- `providers.tf`
- `variables.tf`
- `main.tf`
- `outputs.tf`
- `terraform.tfvars.example`
- `deploy.ps1`
- `GITHUB_ACTIONS_PLATFORM_SETUP.md`

## 4. Cách dùng khuyến nghị

Di chuyển vào folder:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
```

Tạo file biến:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Điền `flagd_sync_token` và giữ baseline mặc định:

```hcl
default_image_tag          = "1.0"
shipping_image_tag         = "1.0-shipping"
bootstrap_from_seed_images = false
enable_shipping_hotfix     = false
```

### Cách A: Flow khuyến nghị với GitHub Actions full platform

1. Chạy workflow:

- `.github/workflows/build-platform-ecr.yml`

2. Sau khi workflow push đủ image lên ECR, deploy từ local:

```powershell
.\deploy.ps1 -SkipBuild
```

Script này sẽ:

1. `terraform init`
2. `terraform apply` để tạo EKS + ECR + sinh `.env.override`
3. `aws eks update-kubeconfig`
4. verify đủ bộ image tag trong ECR
5. `terraform apply` lần 2 để deploy Helm release
6. chờ rollout các deployment chính
7. in danh sách pod để sẵn sàng port-forward/nghiệm thu

Lưu ý: baseline release hiện bật lại `flagd-ui` sidecar để nhóm có thể mở UI local trong cluster khi cần double-check trước khi BTC thao tác với flag trung tâm. Cấu hình hiện tại vẫn không cấp đường ghi ngược vào nguồn flag trung tâm.

Đây là đường chạy nên dùng cho máy local yếu.

### Cách B: Build toàn bộ source ở local

Chỉ dùng khi thật sự cần fallback local:

```powershell
.\deploy.ps1
```

Mặc định lệnh này sẽ gọi:

```powershell
..\deploy\build-push-images.sh
```

để build/push toàn bộ service lên ECR trước khi deploy release.

### Cách C: Chỉ dựng cloud nền tảng

```powershell
terraform init
terraform apply -auto-approve -var-file .\terraform.tfvars -var "deploy_release=false"
```

### Cách D: Sau khi image đã sẵn sàng, deploy release

```powershell
terraform apply -auto-approve -var-file .\terraform.tfvars -var "deploy_release=true"
```

## 5. Logic image hiện tại

### Mặc định

Khi:

```hcl
bootstrap_from_seed_images = false
```

thì chart sẽ dùng:

- repository: ECR của team
- tag base: `default_image_tag`

Ví dụ:

```hcl
default_image_tag = "1.0"
```

sẽ map thành:

- `1.0-frontend`
- `1.0-checkout`
- `1.0-cart`
- `1.0-quote`
- ...

### Service `shipping`

`shipping` vẫn có biến riêng:

```hcl
shipping_image_tag = "1.0-shipping"
```

để khi cần có thể control chặt hơn hoặc rollout riêng.

### Chế độ bootstrap phụ

Nếu cần tạm bootstrap từ seed image:

```hcl
bootstrap_from_seed_images = true
seed_image_repository      = "nghiadaulau/techx-corp"
seed_image_tag             = "1.0"
```

Nhưng đây không còn là hướng khuyến nghị cho baseline chính.

## 6. Vì sao vẫn giữ shipping hotfix

Vì `shipping` từng là service có rủi ro `exec format error` trên node `amd64`.

Hiện tại hướng an toàn là:

1. ưu tiên image `shipping` build từ source
2. push `linux/amd64` lên ECR
3. deploy với `enable_shipping_hotfix = false`
4. chỉ bật hotfix nếu cần rollback nhanh

## 7. Destroy / clear hạ tầng

Khi không còn nhu cầu sử dụng môi trường:

```powershell
terraform destroy -auto-approve -var-file .\terraform.tfvars
```

Lệnh này sẽ gỡ các resource do Terraform quản lý như VPC, EKS, node group, namespace, Helm release và ECR.

## 8. Những điểm đã fix trong runbook này

- `deploy.ps1` ưu tiên Git Bash thay vì vô tình gọi WSL bash
- `deploy.ps1` chờ Docker daemon sẵn sàng trước khi local build
- `deploy.ps1` fail fast nếu lệnh ngoài trả về exit code lỗi
- `deploy.ps1` dùng cách login ECR ổn định hơn trên PowerShell
- `deploy.ps1 -SkipBuild` không còn yêu cầu Docker local
- `deploy.ps1 -SkipBuild` sẽ verify đủ bộ image tag trong ECR trước khi deploy release
- `infra` mặc định dùng ECR của team cho toàn bộ app services
- repo đã được vá thêm lỗi rõ ràng ở `currency` và thiếu folder `rel` của `flagd-ui`

## 9. Điều kiện để flow chạy trơn

1. AWS CLI đang trỏ đúng account mục tiêu
2. Nếu chạy local build: Docker Desktop đang chạy
3. Nếu chạy local build: máy có đủ disk và RAM cho bước build
4. Nếu chạy local build: Git Bash có trên máy
5. `flagd_sync_token` hợp lệ nếu muốn deploy release
6. Nếu chạy CI: GitHub repo đã có secret AWS phù hợp hoặc role OIDC phù hợp

## 9.1 Troubleshooting nhanh

Nếu `deploy.ps1` dừng ở bước Docker với lỗi kiểu:

- `Internal Server Error for API route ... dockerDesktopLinuxEngine`
- `failed to receive status: rpc error ... EOF`
- `error creating overlay mount ... invalid argument`

thì nguyên nhân thường là Docker Desktop / BuildKit trên máy đang ở trạng thái lỗi, không phải Terraform hay Helm.

Nên xử lý theo thứ tự:

1. tắt Docker Desktop hoàn toàn
2. chạy `wsl --shutdown`
3. mở lại Docker Desktop và chờ engine lên hẳn
4. kiểm tra lại:

```powershell
docker version
docker context ls
```

5. chạy lại:

```powershell
.\deploy.ps1
```

## 10. Giới hạn hiện tại

1. Terraform chưa tự verify e2e sau deploy
2. Terraform chưa tự quản lý toàn bộ secret ứng dụng theo chuẩn production
3. Full source-build trên CI hiện đã có khung đầy đủ, nhưng nếu service nào còn lỗi build thì cần xử lý tiếp theo log workflow thay vì quay lại phụ thuộc seed image làm mặc định
