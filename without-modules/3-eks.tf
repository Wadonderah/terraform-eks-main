resource "aws_iam_role" "tf_eks_role" {
  name = "tf_eks_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tf_eks_role"
  }
}

resource "aws_iam_role_policy_attachment" "tf_attach_policy" {
  role       = aws_iam_role.tf_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_eks_cluster" "tf_eks_cluster" {
  name     = var.tf_cluster_name
  role_arn = aws_iam_role.tf_eks_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = [aws_subnet.tf_private_subnet-1.id, aws_subnet.tf_private_subnet-2.id, aws_subnet.tf_public_subnet-1.id, aws_subnet.tf_public_subnet-2.id]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  bootstrap_self_managed_addons = true
  version                       = var.tf_eks_version

  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = {
    "Name" : "EKS cluster"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.tf_attach_policy
  ]
}

output "endpoint" {
  value = aws_eks_cluster.tf_eks_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.tf_eks_cluster.certificate_authority[0].data
}