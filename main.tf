provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "star_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "star-vpc"
  }
}

resource "aws_subnet" "star_subnet" {
  count = 2
  vpc_id                  = aws_vpc.star_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.star_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["eu-west-2a", "eu-west-2b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "star-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "star_igw" {
  vpc_id = aws_vpc.star_vpc.id

  tags = {
    Name = "star-igw"
  }
}

resource "aws_route_table" "star_rt" {
  vpc_id = aws_vpc.star_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.star_igw.id
  }

  tags = {
    Name = "star-route-table"
  }
}

resource "aws_route_table_association" "star_association" {
  count          = 2
  subnet_id      = aws_subnet.star_subnet[count.index].id
  route_table_id = aws_route_table.star_rt.id
}

resource "aws_security_group" "star_cluster_sg" {
  vpc_id = aws_vpc.star_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "star-cluster-sg"
  }
}

resource "aws_security_group" "star_node_sg" {
  vpc_id = aws_vpc.star_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "star-node-sg"
  }
}

resource "aws_eks_cluster" "star" {
  name     = "star-cluster"
  role_arn = aws_iam_role.star_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.star_subnet[*].id
    security_group_ids = [aws_security_group.star_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.star.name
  addon_name      = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "star" {
  cluster_name    = aws_eks_cluster.star.name
  node_group_name = "star-node-group"
  node_role_arn   = aws_iam_role.star_node_group_role.arn
  subnet_ids      = aws_subnet.star_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.star_node_sg.id]
  }
}

resource "aws_iam_role" "star_cluster_role" {
  name = "star-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "star_cluster_role_policy" {
  role       = aws_iam_role.star_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "star_node_group_role" {
  name = "star-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "star_node_group_role_policy" {
  role       = aws_iam_role.star_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "star_node_group_cni_policy" {
  role       = aws_iam_role.star_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "star_node_group_registry_policy" {
  role       = aws_iam_role.star_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "star_node_group_ebs_policy" {
  role       = aws_iam_role.star_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
