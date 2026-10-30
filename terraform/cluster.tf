=========================================================

EKS Cluster IAM Role

=========================================================

resource "aws_iam_role" "eks_cluster_role" {
name = "${var.project_name}-eks-cluster-role"

assume_role_policy = jsonencode({
Version = "2012-10-17"

Statement = [
  {
    Effect = "Allow"

    Principal = {
      Service = "eks.amazonaws.com"
    }

    Action = "sts:AssumeRole"
  }
]


})

tags = {
Name = "${var.project_name}-eks-cluster-role"
}
}

=========================================================

EKS Cluster IAM Policy Attachment

=========================================================

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
role       = aws_iam_role.eks_cluster_role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

=========================================================

EKS Cluster

=========================================================

resource "aws_eks_cluster" "main" {
name     = var.eks_cluster_name
role_arn = aws_iam_role.eks_cluster_role.arn
version  = var.eks_version

vpc_config {
subnet_ids = [
aws_subnet.private.id,
aws_subnet.private_az2.id
]

security_group_ids = [
  aws_security_group.eks_cluster.id
]

endpoint_public_access  = true
endpoint_private_access = true


}

depends_on = [
aws_iam_role_policy_attachment.eks_cluster_policy
]

tags = {
Name = var.eks_cluster_name
}
}

=========================================================

EKS Node IAM Role

=========================================================

resource "aws_iam_role" "node_role" {
name = "${var.project_name}-eks-node-role"

assume_role_policy = jsonencode({
Version = "2012-10-17"

Statement = [
  {
    Effect = "Allow"

    Principal = {
      Service = "ec2.amazonaws.com"
    }

    Action = "sts:AssumeRole"
  }
]


})

tags = {
Name = "${var.project_name}-eks-node-role"
}
}

=========================================================

EKS Worker Node Policies

=========================================================

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
role       = aws_iam_role.node_role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
role       = aws_iam_role.node_role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
role       = aws_iam_role.node_role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

=========================================================

EKS Launch Template (With Max Pods Configured)

=========================================================

data "aws_ami" "eks_default" {
filter {
name   = "name"
values = ["amazon-eks-node-${var.eks_version}-v*"]
}

most_recent = true
owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_launch_template" "eks_nodes" {
name_prefix   = "${var.project_name}-eks-node-"
image_id      = data.aws_ami.eks_default.id
instance_type = var.eks_instance_type

vpc_security_group_ids = [
aws_security_group.eks_cluster.id
]

Custom Bootstrap user_data to increase max pod limit to 20

user_data = base64encode(<<-EOT
#!/bin/bash
set -ex
/etc/eks/bootstrap.sh ${var.eks_cluster_name} --kubelet-extra-args '--max-pods=20'
EOT
)

tag_specifications {
resource_type = "instance"

tags = {
  Name = "${var.project_name}-eks-node"
}


}

lifecycle {
create_before_destroy = true
}
}

=========================================================

EKS Managed Node Group

=========================================================

resource "aws_eks_node_group" "main" {
cluster_name    = aws_eks_cluster.main.name
node_role_arn   = aws_iam_role.node_role.arn
node_group_name = var.eks_node_group_name

subnet_ids = [
aws_subnet.private.id,
aws_subnet.private_az2.id
]

launch_template {
id      = aws_launch_template.eks_nodes.id
version = aws_launch_template.eks_nodes.latest_version
}

scaling_config {
desired_size = var.eks_desired_size
min_size     = var.eks_min_size
max_size     = var.eks_max_size
}

depends_on = [
aws_iam_role_policy_attachment.node_worker_policy,
aws_iam_role_policy_attachment.node_cni_policy,
aws_iam_role_policy_attachment.node_ecr_policy
]

tags = {
Name = "${var.project_name}-eks-node-group"

# Tags required for Cluster Autoscaler
"k8s.io/cluster-autoscaler/enabled"     = "true"
"k8s.io/cluster-autoscaler/eks-cluster" = "owned" 


}
}