# Variables for the IAM module.

variable "project_name" {
  description = "A unique name for the project."
  type        = string
}

variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "efs_id" {
  description = "The ID of the production EFS file system."
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for manifests."
  type        = string
}

variable "s3_bucket_wildcard_arn" {
  description = "Wildcard ARN of the S3 bucket for manifests."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts."
  type        = string
}

variable "account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "ecr_repository_arn" {
  description = "The ARN of the ECR repository containing the manifest generator Docker image."
  type        = string
}