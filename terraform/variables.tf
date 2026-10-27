variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zone_1" {
  description = "First Availability Zone"
  type        = string
}

variable "availability_zone_2" {
  description = "Second Availability Zone"
  type        = string
}

variable "public_subnet_az1_cidr" {
  description = "Public subnet CIDR in AZ1"
  type        = string
}

variable "private_subnet_az1_cidr" {
  description = "Private subnet CIDR in AZ1"
  type        = string
}

variable "public_subnet_az2_cidr" {
  description = "Public subnet CIDR in AZ2"
  type        = string
}

variable "private_subnet_az2_cidr" {
  description = "Private subnet CIDR in AZ2"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "eks_node_group_name" {
  description = "EKS managed node group name"
  type        = string
}

variable "eks_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
}

variable "eks_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
}

variable "eks_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
}

variable "eks_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
}