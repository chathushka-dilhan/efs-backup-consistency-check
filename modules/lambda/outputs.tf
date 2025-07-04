# Outputs for the Lambda module.

output "lambda_function_name" {
  description = "The name of the EFS consistency orchestrator Lambda function."
  value       = aws_lambda_function.efs_orchestrator_lambda.function_name
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for consistency alerts."
  value       = aws_sns_topic.efs_consistency_alerts.arn
}