# ==============================
# VPC
# ==============================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}


# ==============================
# Internet Gateway
# ==============================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# ==============================
# Public Subnet - AZ1
# ==============================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az1_cidr
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project_name}-public-az1"
    "kubernetes.io/role/elb" = "1"
  }
}


# ==============================
# Private Subnet - AZ1
# ==============================

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az1_cidr
  availability_zone = var.availability_zone_1

  tags = {
    Name                              = "${var.project_name}-private-az1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}


# ==============================
# Public Subnet - AZ2
# ==============================

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project_name}-public-az2"
    "kubernetes.io/role/elb" = "1"
  }
}


# ==============================
# Private Subnet - AZ2
# ==============================

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az2_cidr
  availability_zone = var.availability_zone_2

  tags = {
    Name                              = "${var.project_name}-private-az2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}


# ==============================
# Elastic IP for NAT Gateway
# ==============================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}


# ==============================
# NAT Gateway
# ==============================

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}


# ==============================
# Public Route Table
# ==============================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}


# ==============================
# Public Route
# ==============================

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


# ==============================
# Public Route Table Association - AZ1
# ==============================

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# ==============================
# Public Route Table Association - AZ2
# ==============================

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}


# ==============================
# Private Route Table
# ==============================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}


# ==============================
# Private Route
# ==============================

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}


# ==============================
# Private Route Table Association - AZ1
# ==============================

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


# ==============================
# Private Route Table Association - AZ2
# ==============================

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private.id
}


# ==============================
# EKS Cluster Security Group
# ==============================

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-cluster-sg"
  }
}


# ==============================
# EKS Node Security Group
# ==============================

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow nodes to communicate with cluster"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    description = "Allow node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-node-sg"
  }
}


# Allow EKS control plane to communicate with worker kubelets
resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_cluster_10250" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id

  description = "Allow EKS control plane to reach worker kubelet"
  ip_protocol = "tcp"
  from_port   = 10250
  to_port     = 10250
}


# =========================================================
# EKS Worker Node Launch Template
# =========================================================

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"

  vpc_security_group_ids = [
    aws_security_group.eks_nodes.id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name      = "${var.project_name}-eks-worker"
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
