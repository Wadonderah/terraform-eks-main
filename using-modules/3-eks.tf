module "eks" {
  source = "terraform-aws-modules/eks/aws"
   version =  "~> 20.0"

  cluster_name                    = var.eks_cluster_name
  cluster_version                 = var.eks_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = "ac01234b-00d9-40f6-ac95-e42345f78b00"
    resources        = ["secrets"]
  }]

  vpc_id     = module.vpc.default_vpc_id
  subnet_ids =concat(module.vpc.public_subnets,module.vpc.private_subnets)

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = "m6i.large"
    update_launch_template_default_version = true
    iam_role_additional_policies           = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  }

  self_managed_node_groups = {
    one = {
      name = "spot-1"

      public_ip    = true
      max_size     = 5
      desired_size = 2

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 10
          spot_allocation_strategy                 = "capacity-optimized"
        }

        override = [
          {
            instance_type     = "m5.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m6i.large"
            weighted_capacity = "2"
          },
        ]
      }

      pre_bootstrap_user_data = <<-EOT
      echo "foo"
      export FOO=bar
      EOT

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"

      post_bootstrap_user_data = <<-EOT
      cd /tmp
      sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      sudo systemctl enable amazon-ssm-agent
      sudo systemctl start amazon-ssm-agent
      EOT
    }
  }

  # EKS Managed Node Group(s)
#   eks_managed_node_group_defaults = {
#     ami_type               = "AL2_x86_64"
#     disk_size              = 50
#     instance_types         = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
#     vpc_security_group_ids = [aws_security_group.additional.id]
#   }

#   eks_managed_node_groups = {
#     blue = {}
#     green = {
#       min_size     = 1
#       max_size     = 10
#       desired_size = 1

#       instance_types = ["t3.large"]
#       capacity_type  = "SPOT"
#       labels = {
#         Environment = "test"
#         GithubRepo  = "terraform-aws-eks"
#         GithubOrg   = "terraform-aws-modules"
#       }
#       taints = {
#         dedicated = {
#           key    = "dedicated"
#           value  = "gpuGroup"
#           effect = "NO_SCHEDULE"
#         }
#       }
#       tags = {
#         ExtraTag = "example"
#       }
#     }
#   }

  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "default"
        }
      ]

      tags = {
        Owner = "test"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}