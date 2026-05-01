resource "aws_iam_role" "cluster" {
    name = "${var.cluster_name}-cluster-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "eks.amazonaws.com"
            }
        }]
    })

}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role        =  aws_iam_role.cluster.name
}

resource "aws_iam_role" "node_group" {
    name = "${var.cluster_name}-node-group-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "node_group_policy" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role        =  aws_iam_role.node_group.name
}


resource "aws_iam_role_policy_attachment" "CNI_policy" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role        =  aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role        =  aws_iam_role.node_group.name
}

resource "aws_eks_cluster" "main" {
    name        = var.cluster_name
    version     = var.cluster_version
    role_arn    = aws_iam_role.cluster.arn 


    vpc_config {
        subnet_ids = var.private_subnet_ids
        endpoint_private_access = true
        endpoint_public_access  = true 
    }

    depends_on = [
        aws_iam_role_policy_attachment.cluster_policy
    ]
}

resource "aws_eks_node_group" "node_group" {
    cluster_name    = aws_eks_cluster.main.name
    node_group_name = "${var.cluster_name}-node-group"
    node_role_arn   = aws_iam_role.node_group.arn 
    subnet_ids      = var.private_subnet_ids
    instance_types  = [var.node_instance_type]
    scaling_config {
        desired_size = var.node_desired_size
        min_size     = var.node_min_size
        max_size     = var.node_max_size
    }
    depends_on = [aws_iam_role_policy_attachment.node_group_policy, aws_iam_role_policy_attachment.ec2_policy, aws_iam_role_policy_attachment.CNI_policy]

}