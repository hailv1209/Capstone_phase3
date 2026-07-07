# GitHub Actions cho toàn bộ platform

## 1. Mục tiêu

Workflow này build toàn bộ service ứng dụng trực tiếp từ source rồi push lên ECR của team.

Đây là hướng khuyến nghị cho CDO-02 khi:

- máy local yếu
- Docker Desktop không ổn định
- muốn chủ động cập nhật code mọi service mà không phụ thuộc seed image upstream

Workflow chính:

- `.github/workflows/build-platform-ecr.yml`

Workflow phụ:

- `.github/workflows/build-shipping-ecr.yml`

Workflow phụ chỉ hữu ích khi muốn rebuild riêng `shipping`. Với baseline chung, nên dùng workflow full platform.

## 2. Build từ source nào

Workflow full platform build trực tiếp từ source của repo:

- `techx-corp-platform/src/accounting`
- `techx-corp-platform/src/ad`
- `techx-corp-platform/src/cart`
- `techx-corp-platform/src/checkout`
- `techx-corp-platform/src/currency`
- `techx-corp-platform/src/email`
- `techx-corp-platform/src/flagd-ui`
- `techx-corp-platform/src/fraud-detection`
- `techx-corp-platform/src/frontend`
- `techx-corp-platform/src/frontend-proxy`
- `techx-corp-platform/src/image-provider`
- `techx-corp-platform/src/kafka`
- `techx-corp-platform/src/llm`
- `techx-corp-platform/src/load-generator`
- `techx-corp-platform/src/payment`
- `techx-corp-platform/src/product-catalog`
- `techx-corp-platform/src/product-reviews`
- `techx-corp-platform/src/quote`
- `techx-corp-platform/src/recommendation`
- `techx-corp-platform/src/shipping`

Tức là baseline mặc định không còn đi theo hướng dùng `nghiadaulau/techx-corp` cho các service chính.

## 3. Cấp quyền AWS cho GitHub

### Cách khuyến nghị: OIDC

Repo hiện hỗ trợ đọc role ARN từ:

- repo variable `AWS_ROLE_TO_ASSUME`
- hoặc repo secret `AWS_ROLE_TO_ASSUME`

Khuyến nghị dùng repo variable vì role ARN không phải secret.

Ví dụ:

```text
arn:aws:iam::593777010472:role/GitHubActionsCapstonePhase3
```

Role tối thiểu cần có:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:CompleteLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:InitiateLayerUpload`
- `ecr:PutImage`
- `ecr:BatchGetImage`
- `ecr:DescribeRepositories`
- `ecr:CreateRepository`

### Cách nhanh hơn: GitHub secrets

Nếu chưa dựng OIDC ngay, thêm:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## 4. Cách chạy workflow full platform

Vào tab `Actions` trên GitHub rồi chạy:

- `Build Platform To ECR`

Input khuyến nghị:

- `aws_region`: `us-east-1`
- `ecr_repository`: `techx-corp`
- `base_image_tag`: `1.0`
- `push_sha_tags`: `true`

Kết quả sẽ push:

- `1.0-accounting`
- `1.0-ad`
- `1.0-cart`
- ...
- `1.0-shipping`

và nếu bật `push_sha_tags`, workflow cũng push thêm:

- `<sha>-accounting`
- `<sha>-ad`
- ...
- `<sha>-shipping`

## 5. Cấu hình infra để deploy full source-built images

Trong `infra/terraform.tfvars`, giữ:

```hcl
default_image_tag          = "1.0"
shipping_image_tag         = "1.0-shipping"
bootstrap_from_seed_images = false
enable_shipping_hotfix     = false
```

Ý nghĩa:

- mọi service chính sẽ lấy image từ ECR của team
- riêng `shipping` vẫn có tag explicit để control chặt hơn
- không bootstrap từ seed image

## 6. Deploy sau khi workflow build xong

Từ máy local:

```powershell
cd D:\Xbrain\techx-phase3-cdo02\infra
.\deploy.ps1 -SkipBuild
```

Lúc này script sẽ:

1. dựng hoặc refresh hạ tầng Terraform
2. verify đủ image tag trong ECR
3. deploy Helm release lên EKS
4. chờ rollout workload

## 7. Cách kiểm tra image trong ECR

Ví dụ kiểm tra tất cả tag `1.0-*`:

```powershell
aws ecr describe-images `
  --repository-name techx-corp `
  --region us-east-1 `
  --query "imageDetails[?imageTags!=null].[imageTags,imagePushedAt]" `
  --output table
```

## 8. Khi nào mới dùng seed image

Chỉ dùng khi thật sự cần bootstrap tạm hoặc khi pipeline source-build đang hỏng.

Nếu muốn bật chế độ đó:

```hcl
bootstrap_from_seed_images = true
seed_image_repository      = "nghiadaulau/techx-corp"
seed_image_tag             = "1.0"
```

Nhưng đây chỉ là đường phụ, không phải hướng vận hành khuyến nghị cho nhóm nữa.

## 9. Lưu ý thực tế

1. Workflow full platform sẽ tốn thời gian hơn workflow riêng `shipping`.
2. `deploy.ps1 -SkipBuild` là đường deploy phù hợp nhất cho máy local yếu.
3. Repo hiện đã được vá thêm một số lỗi source rõ ràng như phần `currency` và thiếu folder `rel` của `flagd-ui`, nhưng nếu CI báo thêm service lỗi build thì nên xử lý tiếp từng service dựa trên log của workflow.
