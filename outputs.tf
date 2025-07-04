# Exposes relevant outputs from the child modules.

output "s3_bucket_name" {
  description = "The name of the S3 bucket for EFS manifests."
  value       = module.s3_manifest_bucket.s3_bucket_name
}

output "lambda_function_name" {
  description = "The name of the EFS consistency orchestrator Lambda function."
  value       = module.efs_orchestrator_lambda.lambda_function_name
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for consistency alerts."
  value       = module.efs_orchestrator_lambda.sns_topic_arn
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster created for manifest generation."
  value       = module.ecs_manifest_generator.ecs_cluster_name
}

output "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition for manifest generation."
  value       = module.ecs_manifest_generator.ecs_task_definition_arn
}