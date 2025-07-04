# Manages the Lambda function, CloudWatch Event Rule, and SNS Topic.

# SNS Topic for Alerts
resource "aws_sns_topic" "efs_consistency_alerts" {
  name = "${var.project_name}-consistency-alerts"
  tags = {
    Name = "${var.project_name}-consistency-alerts"
  }
}

# Lambda Function for Orchestration
resource "aws_lambda_function" "efs_orchestrator_lambda" {
  function_name = "${var.project_name}-orchestrator-lambda"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  role          = var.orchestrator_lambda_role_arn
  timeout       = 900 # 15 minutes, adjust based on expected restore/comparison time
  memory_size   = 512 # Adjust based on memory needs

  # Lambda deployment package (replace with your actual zip file)
  filename         = "lambda_package.zip"
  source_code_hash = filebase64sha256("lambda_package.zip")

  environment {
    variables = {
      S3_BUCKET_NAME          = var.s3_bucket_name
      EFS_ID                  = var.efs_id
      VPC_ID                  = var.vpc_id
      SUBNET_IDS              = jsonencode(var.subnet_ids)
      SECURITY_GROUP_IDS      = jsonencode(var.security_group_ids)
      ECS_CLUSTER_NAME        = var.ecs_cluster_name
      ECS_TASK_DEFINITION_ARN = var.ecs_task_definition_arn
      ECS_CONTAINER_NAME      = var.ecs_container_name
      PROJECT_NAME            = var.project_name
      SNS_TOPIC_ARN           = aws_sns_topic.efs_consistency_alerts.arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = {
    Name = "${var.project_name}-orchestrator-lambda"
  }
}

# CloudWatch Event Rule to Trigger Lambda on AWS Backup Completion
resource "aws_cloudwatch_event_rule" "backup_completion_rule" {
  name        = "${var.project_name}-backup-completion-rule"
  description = "Triggers Lambda when an EFS backup job completes successfully."

  event_pattern = jsonencode({
    "source" : ["aws.backup"],
    "detail-type" : ["Backup Job State Change"],
    "detail" : {
      "resourceType" : ["EFS"],
      "state" : ["COMPLETED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "backup_completion_target" {
  rule      = aws_cloudwatch_event_rule.backup_completion_rule.name
  target_id = "EFSBackupOrchestratorLambda"
  arn       = aws_lambda_function.efs_orchestrator_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.efs_orchestrator_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_completion_rule.arn
}