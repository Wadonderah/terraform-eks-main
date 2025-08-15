resource "aws_iam_role" "tf_eks_farget_profile_role" {
  name = "tf_eks_farget_profile_role"

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
          Service = "eks-fargate-pods.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tf_eks_farget_profile_role"
  }
}


resource "aws_iam_role_policy_attachment" "tf_fargate_attach_policy" {
  role       = aws_iam_role.tf_eks_farget_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}


resource "aws_eks_fargate_profile" "tf_fargate_profile" {
  cluster_name           = aws_eks_cluster.tf_eks_cluster.name
  fargate_profile_name   = "tf_fargate_profile"
  pod_execution_role_arn = aws_iam_role.tf_eks_farget_profile_role.arn
  subnet_ids             = [aws_subnet.tf_private_subnet-1.id, aws_subnet.tf_private_subnet-2.id]

  selector {
    namespace = "kube-system"
  }
  selector {
    namespace = "default"
  }
  depends_on = [aws_iam_role_policy_attachment.tf_fargate_attach_policy]
}