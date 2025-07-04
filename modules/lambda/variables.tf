# Variables for the Lambda module.

variable "project_name" {
  description = "A unique name for the project."
  type        = string
}

variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "orchestrator_lambda_role_arn" {
  description = "ARN of the IAM role for the orchestrator Lambda function."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for manifests."
  type        = string
}

variable "efs_id" {
  description = "The ID of the production EFS file system."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs for Lambda and ECS deployment."
  type        = list(string)
}

variable "security_group_ids" {
  description = "A list of security group IDs for Lambda and ECS."
  type        = list(string)
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster where Fargate tasks will run."
  type        = string
}

variable "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition for manifest generation."
  type        = string
}

variable "ecs_container_name" {
  description = "The name of the container within the ECS task definition."
  type        = string
}