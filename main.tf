# This file orchestrates the deployment of all child modules.
# It configures the AWS provider, sets up data sources, and calls the necessary modules for S3 bucket creation,
# IAM role management, ECS manifest generation, and Lambda orchestration.

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# --- S3 Bucket Module ---
module "s3_manifest_bucket" {
  source = "./modules/s3_bucket"

  project_name   = var.project_name
  s3_bucket_name = var.s3_bucket_name
}

# --- IAM Module ---
module "iam_roles" {
  source = "./modules/iam"

  project_name           = var.project_name
  aws_region             = var.aws_region
  efs_id                 = var.efs_id
  s3_bucket_arn          = module.s3_manifest_bucket.s3_bucket_arn
  s3_bucket_wildcard_arn = "${module.s3_manifest_bucket.s3_bucket_arn}/*"
  sns_topic_arn          = module.efs_orchestrator_lambda.sns_topic_arn # Pass output from lambda module
  account_id             = data.aws_caller_identity.current.account_id
  ecr_repository_arn     = var.ecr_repository_arn # Pass ECR ARN for Fargate permissions
}

# --- ECS Manifest Generator Module (for both original and temporary manifests) ---
module "ecs_manifest_generator" {
  source = "./modules/ecs_manifest_generator"

  project_name                = var.project_name
  aws_region                  = var.aws_region
  vpc_id                      = var.vpc_id
  subnet_ids                  = var.subnet_ids
  security_group_ids          = var.security_group_ids
  efs_id                      = var.efs_id
  ecs_task_execution_role_arn = module.iam_roles.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam_roles.ecs_task_role_arn
  ecr_image_uri               = var.ecr_image_uri
  s3_bucket_name              = module.s3_manifest_bucket.s3_bucket_name
}

# --- Lambda Orchestrator Module ---
module "efs_orchestrator_lambda" {
  source = "./modules/lambda"

  project_name                 = var.project_name
  aws_region                   = var.aws_region
  orchestrator_lambda_role_arn = module.iam_roles.orchestrator_lambda_role_arn
  s3_bucket_name               = module.s3_manifest_bucket.s3_bucket_name
  efs_id                       = var.efs_id
  vpc_id                       = var.vpc_id
  subnet_ids                   = var.subnet_ids
  security_group_ids           = var.security_group_ids
  ecs_cluster_name             = module.ecs_manifest_generator.ecs_cluster_name
  ecs_task_definition_arn      = module.ecs_manifest_generator.ecs_task_definition_arn
  ecs_container_name           = module.ecs_manifest_generator.ecs_container_name
}