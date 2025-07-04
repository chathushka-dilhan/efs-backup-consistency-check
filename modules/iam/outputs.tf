# Outputs for the IAM module.

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution role."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS Task role for manifest generation."
  value       = aws_iam_role.ecs_task_role.arn
}

output "orchestrator_lambda_role_arn" {
  description = "ARN of the IAM role for the EFS orchestrator Lambda function."
  value       = aws_iam_role.efs_orchestrator_lambda_role.arn
}