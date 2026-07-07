output "aws_region" {
  value       = var.aws_region
  description = "AWS region used by this stack."
}

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "Created EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint."
}

output "cluster_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "OIDC issuer URL for the cluster."
}

output "namespace" {
  value       = var.namespace
  description = "Kubernetes namespace for the TechX app."
}

output "release_name" {
  value       = var.release_name
  description = "Helm release name."
}

output "nodegroup_name" {
  value       = var.nodegroup_name
  description = "Managed nodegroup name."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "Created VPC ID."
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs."
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.techx_corp.repository_url
  description = "ECR repository URL for app images."
}

output "default_image_repository" {
  value       = local.effective_default_image_repository
  description = "Effective repository used by the Helm chart for main app services."
}

output "default_image_tag" {
  value       = local.effective_default_image_tag
  description = "Effective base image tag used by the Helm chart for main app services."
}

output "shipping_image_tag" {
  value       = local.effective_shipping_image_tag
  description = "Effective shipping image tag expected in ECR."
}

output "env_override_file" {
  value       = local_file.env_override.filename
  description = "Generated .env.override path used by build-push-images.sh."
}

output "release_enabled" {
  value       = var.deploy_release
  description = "Whether Terraform is configured to deploy the Helm release."
}
