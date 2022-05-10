variable "app_name" {
    type = string
    default = "counterparty-fee-calculator"
    description = "The name of the Kubernetes App that will be deployed to EKS"
}
variable "app_port" {
    type = number
    default = 8080
    description = "The port that the Kubernetes App listens on within the container. This is also the port that will be exposed in the provisioned load balancer"
}
variable "ec2_unsupported_availability_zones" {
    type = set(string)
    default = [ "us-east-1d", "us-east-1e", "us-east-1f" ]
    description = "List of availability zones which does not support all EC2 instance types"
}
variable "docker_image" {
    type = string
    default = "dk.jonatanbuus/counterparty-fee-calculator:latest"
    description = "The name of the container image in ECR that the created App Runner Service will run."
}
variable "eks_cluster_name" {
    type = string
    default = "my-eks-cluster"
    description = "The name of the created EKS cluster"
}
variable "repository" {
    type = string
    default = "eks-repository"
    description = "The name of the container repository that will be created in ECR."
}