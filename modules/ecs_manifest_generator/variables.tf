# Variables for the ECS manifest generator module.

variable "project_name" {
  description = "A unique name for the project."
  type        = string
}

variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs for ECS deployment."
  type        = list(string)
}

variable "security_group_ids" {
  description = "A list of security group IDs for ECS."
  type        = list(string)
}

variable "efs_id" {
  description = "The ID of the production EFS file system."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution role."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS Task role for manifest generation."
  type        = string
}

variable "ecr_image_uri" {
  description = "The URI of the Docker image for the manifest generator."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for manifests."
  type        = string
}