resource "aws_iam_role" "tf_eks_ng_role" {
  name = "tf_eks_node_group_role"

  # Terraform's "jsonencode" function converts a tf_eks_node_group_role
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tf_eks_ng_role"
  }
}


resource "aws_iam_role_policy_attachment" "tf_worker_node_policy" {
  role       = aws_iam_role.tf_eks_ng_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


resource "aws_iam_role_policy_attachment" "tf_eks_cni_policy" {
  role       = aws_iam_role.tf_eks_ng_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "tf_eks_container_policy" {
  role       = aws_iam_role.tf_eks_ng_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "tf_eks_node_group" {
  cluster_name    = aws_eks_cluster.tf_eks_cluster.name
  node_group_name = "tf_eks_node_group"
  node_role_arn   = aws_iam_role.tf_eks_ng_role.arn
  subnet_ids      = [aws_subnet.tf_private_subnet-1.id, aws_subnet.tf_private_subnet-2.id]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.tf_worker_node_policy,
    aws_iam_role_policy_attachment.tf_eks_cni_policy,
    aws_iam_role_policy_attachment.tf_eks_container_policy,
  ]
}