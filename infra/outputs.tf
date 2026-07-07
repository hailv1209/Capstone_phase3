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
