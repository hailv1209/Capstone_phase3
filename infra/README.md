# Infra Scaffold cho CDO-02

## 1. Mục đích

Folder `infra/` chứa bộ Terraform scaffold để nhóm CDO-02 có thể tạo lại hạ tầng cơ bản cho Phase 3 bằng cách đơn giản hơn.

Phiên bản scaffold này ưu tiên:

- Tạo VPC
- Tạo EKS cluster
- Tạo managed node group
- Tạo ECR repository `techx-corp`

Nó chưa bao gồm:

- Deploy ứng dụng bằng Helm
- Tạo secret runtime
- Patch `shipping`

Nhưng nó đủ để dựng lại nền tảng cloud, sau đó team tiếp tục bằng `kubectl`/`helm`.

## 2. Các file chính

- `versions.tf`
- `providers.tf`
- `variables.tf`
- `main.tf`
- `outputs.tf`
- `terraform.tfvars.example`

## 3. Cách dùng nhanh

Di chuyển vào folder:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
```

Tạo file biến:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Sửa `terraform.tfvars` nếu cần, sau đó chạy:

```powershell
terraform init
terraform plan
terraform apply
```

Sau khi apply xong, cập nhật kubeconfig:

```powershell
aws eks update-kubeconfig --name techx-tf3 --region us-east-1
kubectl get nodes
```

Tạo ECR login:

```powershell
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 593777010472.dkr.ecr.us-east-1.amazonaws.com
```

## 4. Những gì cần làm tiếp sau khi có cluster

1. Cập nhật `techx-corp-platform/.env.override`
2. Build/push image lên ECR
3. Cập nhật `deploy/values-flagd-sync.yaml`
4. `helm dependency build .\techx-corp-chart`
5. Deploy chart
6. Nếu `shipping` lỗi `exec format error` thì áp dụng hotfix runtime

## 5. Lưu ý

1. Scaffold này tạo mới hạ tầng, không import cluster `eksctl` hiện tại.
2. Nếu muốn quản lý cluster live bằng Terraform, cần làm một bước import/chuyển đổi riêng.
3. Default đang bám sát cấu hình cluster live đã dựng ngày `2026-07-07`: `us-east-1`, `1.30`, `t3.large`, `2` nodes.
