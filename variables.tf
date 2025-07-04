# Defines all input variables for the root module.

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1" # Change to desired region
}

variable "project_name" {
  description = "A unique name for the project, used as a prefix for resources."
  type        = string
  default     = "efs-backup-verifier"
}

variable "efs_id" {
  description = "The ID of the EFS file system to be backed up and verified."
  type        = string
  # Example: default = "fs-xxxxxxxxxxxxxxxxx"
}

variable "s3_bucket_name" {
  description = "Name for the S3 bucket to store EFS manifests. Must be globally unique."
  type        = string
  # Example: default = "efs-backup-manifests-12345"
}

variable "vpc_id" {
  description = "The ID of the VPC where resources will be deployed."
  type        = string
  # Example: default = "vpc-xxxxxxxxxxxxxxxxx"
}

variable "subnet_ids" {
  description = "A list of subnet IDs for Lambda and ECS deployment."
  type        = list(string)
  # Example: default = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]
}

variable "security_group_ids" {
  description = "A list of security group IDs for Lambda and ECS."
  type        = list(string)
  # Example: default = ["sg-xxxxxxxxxxxxxxxxx"]
}

variable "ecr_repository_arn" {
  description = "The ARN of the ECR repository containing the manifest generator Docker image."
  type        = string
  # Example: default = "arn:aws:ecr:us-east-1:123456789012:repository/ecr-repo"
}

variable "ecr_image_uri" {
  description = "The URI of the Docker image for the manifest generator (e.g., ecr-repo/efs-manifest-generator:latest)."
  type        = string
  # Example: default = "[123456789012.dkr.ecr.us-east-1.amazonaws.com/ecr-repo:latest](https://123456789012.dkr.ecr.us-east-1.amazonaws.com/ecr-repo:latest)"
}