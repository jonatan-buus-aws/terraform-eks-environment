terraform {
  required_providers {
		aws = {
			source  = "hashicorp/aws"
#			version = "3.50.0"
		}
		kubernetes = {
			source  = "hashicorp/kubernetes"
#			version = "~> 2.3"
		}
		kubernetes-alpha = {
			source = "hashicorp/kubernetes-alpha"
#			version = "0.3.0"
		}
	}
}

# Configure the AWS Provider
provider "aws" {
	region = "eu-west-1"
}

provider "kubernetes" {
	config_path = "~/.kube/config"
}
provider "kubernetes-alpha" {
	config_path = "~/.kube/config"
}