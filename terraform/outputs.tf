# ==============================
# VPC ID
# ==============================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}


# ==============================
# Public Subnet IDs
# ==============================

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value = [
    aws_subnet.public.id,
    aws_subnet.public_az2.id
  ]
}


# ==============================
# Private Subnet IDs
# ==============================

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value = [
    aws_subnet.private.id,
    aws_subnet.private_az2.id
  ]
}


# ==============================
# NAT Gateway ID
# ==============================

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.nat.id
}


# ==============================
# EKS Cluster Name
# ==============================

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}


# ==============================
# EKS Cluster Endpoint
# ==============================

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}


# ==============================
# EKS Node Group Name
# ==============================

output "eks_node_group_name" {
  description = "Name of the EKS managed node group"
  value       = aws_eks_node_group.main.node_group_name
}