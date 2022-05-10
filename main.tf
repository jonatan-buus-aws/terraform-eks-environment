locals {
	eks_service_account_name = "eks-service-account-for-${var.eks_cluster_name}"
	eks_iam_roles = { "eks_cluster" = { name = "${var.eks_cluster_name}-role",
										policy = module.eks.eks_standard_policies.eks_cluster,
										description = "Role for running an EKS Cluster",
										policy_attachments = [ "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy", "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController" ],
										tags = { } },
					  "eks_node_group" = { name = "ec2-node-group-for-${var.eks_cluster_name}",
					  					   policy = module.eks.eks_standard_policies.ec2_node_group,
										   description = "Role for an EKS Cluster's node pool",
										   policy_attachments = [ "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" ],
										   tags = { } },
					  "eks_fargate" = { name = "fargate-pods-for-${var.eks_cluster_name}",
					  					policy = module.eks.eks_standard_policies.fargate,
										description = "Allows access to other AWS service resources that are required to run Amazon EKS pods on AWS Fargate",
										policy_attachments = [ "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy" ],
										tags = { } } }
	other_iam_roles = { "eks_service_account" = { name = local.eks_service_account_name,
												  policy = module.eks.eks_service_acccount_policy,
												  description = "Role for an EKS Cluster's service account",
												  policy_attachments = [ "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" ],
												  tags = { "ServiceAccountName" = "aws-node", "ServiceAccountNameSpace" = "kube-system" } } }
	docker_image_tag = split(":", var.docker_image)[1]
}

module "vpc" {
	source = "github.com/jonatan-buus-aws/terraform-modules/vpc"
	vpc_name = "${var.eks_cluster_name}-vpc"
	vpc_tags = { "env" = "eks", "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" }
	vpc_unsupported_ec2_availability_zones = var.ec2_unsupported_availability_zones
	vpc_secure_default_vpc = false
}

# Create roles for the EKS Cluster separately to prevent re-creation when new roles for other infrastructure components are added to the list
module "iam_eks_roles" {
	source = "github.com/jonatan-buus-aws/terraform-modules/iam-role"

	for_each = local.eks_iam_roles

	iam_role_name = each.value.name
	iam_assume_role_policy = each.value.policy
	iam_role_description = each.value.description
	iam_policy_attachments = each.value.policy_attachments
	iam_tags = each.value.tags
}
# Create roles for infrastructure components other than the EKS cluster as they are not recreated when a new role is added to the list
module "iam_other_roles" {
	source = "github.com/jonatan-buus-aws/terraform-modules/iam-role"
	
	for_each = local.other_iam_roles

	iam_role_name = each.value.name
	iam_assume_role_policy = each.value.policy
	iam_role_description = each.value.description
	iam_policy_attachments = lookup(each.value, "policy_attachments", [])
	iam_policies = lookup(each.value, "policies", [])
	iam_tags = each.value.tags
}

module "eks" {
	source = "github.com/jonatan-buus-aws/terraform-modules/eks"

	eks_cluster_name = var.eks_cluster_name
	eks_cluster_role = module.iam_eks_roles["eks_cluster"].iam_role.name
	eks_cluster_subnets = values(module.vpc.vpc_eks_subnets)
	eks_service_account_role = local.eks_service_account_name
	eks_fargate_role = module.iam_eks_roles["eks_fargate"].iam_role.name
	eks_node_role = module.iam_eks_roles["eks_node_group"].iam_role.name
	eks_secure_cluster = false
	eks_node_config = { ami_type = "AL2_x86_64",
						instance_type = "t3.medium",
						disk_size = 20,
						labels = { },
						launch_template_name = "",
						launch_template_version = "",
						subnets = values(module.vpc.vpc_private_subnets) }
/*
	eks_fargate_config = { name = "",
						   namespace = "my-fargate-pods",
						   subnets = values(module.vpc.vpc_private_subnets) }
*/
}

module "ecr" {
	source = "github.com/jonatan-buus-aws/terraform-modules/ecr"

	ecr_repository_name = var.repository
}
resource "null_resource" "docker" {
	provisioner "local-exec" {
		command = "aws ecr get-login-password | docker login --username AWS --password-stdin ${module.ecr.ecr_repository_url}"
	}
	provisioner "local-exec" {
		command = "docker tag ${var.docker_image} ${module.ecr.ecr_repository_url}:${local.docker_image_tag}"
	}
	provisioner "local-exec" {
		command = "docker push ${module.ecr.ecr_repository_url}:${local.docker_image_tag}"
	}
}
module "k8s_app" {
	depends_on = [ null_resource.docker ]

	source = "github.com/jonatan-buus-aws/terraform-modules/k8s-app"

	k8s_app_name = var.app_name
	k8s_app_docker_image = "${module.ecr.ecr_repository_url}:${local.docker_image_tag}"
	k8s_app_port = var.app_port
}

resource "null_resource" "output" {
	provisioner "local-exec" {
		command = "echo API Documentation available at: http://${module.k8s_app.load_balancer_hostname}:${var.app_port}/swagger-ui/"
	}
}