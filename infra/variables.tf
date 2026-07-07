variable "aws_region" {
  type        = string
  description = "AWS region to deploy the platform."
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "techx-tf3"
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version."
  default     = "1.30"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the TechX release."
  default     = "techx-tf3"
}

variable "release_name" {
  type        = string
  description = "Helm release name."
  default     = "techx-corp"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs."
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs."
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "nodegroup_name" {
  type        = string
  description = "Managed nodegroup name."
  default     = "ng-core"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for workers."
  default     = "t3.large"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes."
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes."
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes."
  default     = 3
}

variable "node_disk_size" {
  type        = number
  description = "Disk size in GiB for worker nodes."
  default     = 80
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository name for app images."
  default     = "techx-corp"
}

variable "image_version" {
  type        = string
  description = "Base image version tag used by build-push-images.sh."
  default     = "1.0"
}

variable "demo_version" {
  type        = string
  description = "Demo version tag used by the chart release."
  default     = "1.0"
}

variable "shipping_image_tag" {
  type        = string
  description = "Exact shipping image tag to deploy from ECR. Leave empty to use <demo_version>-shipping."
  default     = ""
}

variable "bootstrap_from_seed_images" {
  type        = bool
  description = "Use upstream seed images instead of the team's ECR for the main app services."
  default     = false
}

variable "seed_image_repository" {
  type        = string
  description = "Seed image repository used only when bootstrap_from_seed_images=true."
  default     = "nghiadaulau/techx-corp"
}

variable "seed_image_tag" {
  type        = string
  description = "Seed image tag used only when bootstrap_from_seed_images=true."
  default     = "1.0"
}

variable "default_image_tag" {
  type        = string
  description = "Base tag for source-built images in the team's ECR. Helm will expand this to <tag>-<service>."
  default     = "1.0"
}

variable "flagd_sync_token" {
  type        = string
  description = "Bearer token used by flagd to sync with the central source."
  sensitive   = true
  default     = ""
}

variable "deploy_release" {
  type        = bool
  description = "Whether Terraform should also deploy the Helm release after the cluster and ECR are ready."
  default     = false
}

variable "enable_shipping_hotfix" {
  type        = bool
  description = "Whether to include the known-good shipping hotfix in the Helm release values."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to resources."
  default = {
    Environment = "phase3"
    Team        = "TF3"
    Project     = "techx-corp"
    ManagedBy   = "terraform"
  }
}
