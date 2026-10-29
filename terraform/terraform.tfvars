aws_region   = "ap-south-1"
project_name = "One-Click-Infra"

vpc_cidr = "10.0.0.0/16"

availability_zone_1 = "ap-south-1a"
availability_zone_2 = "ap-south-1b"

public_subnet_az1_cidr  = "10.0.1.0/24"
private_subnet_az1_cidr = "10.0.2.0/24"

public_subnet_az2_cidr  = "10.0.3.0/24"
private_subnet_az2_cidr = "10.0.4.0/24"

eks_cluster_name    = "eks-cluster"
eks_version         = "1.35"
eks_node_group_name = "node-group"

eks_instance_type = "t2.micro"

eks_desired_size = 2
eks_min_size     = 1
eks_max_size     = 3