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
