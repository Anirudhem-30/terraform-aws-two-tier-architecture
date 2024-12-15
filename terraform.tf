# Terraform block specifies the backend and required providers
terraform {
  # Configure the Terraform Cloud as the backend for state storage
  cloud {
    organization = "demo-cloud-backend"  # Name of the organization in Terraform Cloud

    workspaces {
      name = "dev-cli"  # Workspace name where this configuration will be applied
    }
  }

  # Define the required providers for this configuration
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Specifies the Terraform registry as the source for the AWS provider
      version = "5.42.0"         # Pin the version of the AWS provider to ensure consistency
    }
  }
}

# Provider block configures the AWS provider
provider "aws" {
  region = "us-east-1"  # Specifies the AWS region where resources will be provisioned
}