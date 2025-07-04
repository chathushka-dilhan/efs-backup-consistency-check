# Manages IAM roles and policies for the solution.

# IAM Role for ECS Task Execution (Fargate)
# This role is used by the ECS agent to pull images and publish logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add ECR read permissions
resource "aws_iam_role_policy" "ecs_task_execution_ecr_policy" {
  name = "${var.project_name}-ecs-task-execution-ecr-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = var.ecr_repository_arn
      }
    ]
  })
}


# IAM Role for ECS Task (Manifest Generator)
# This role is assumed by the actual container running the manifest generation script.
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          var.s3_bucket_arn,
          var.s3_bucket_wildcard_arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ],
        Resource = [
          "arn:aws:elasticfilesystem:${var.aws_region}:${var.account_id}:file-system/${var.efs_id}"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*" # Broad for simplicity, refine as needed
      }
    ]
  })
}

# IAM Role for EFS Backup Consistency Orchestrator Lambda
resource "aws_iam_role" "efs_orchestrator_lambda_role" {
  name = "${var.project_name}-orchestrator-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-orchestrator-lambda-role"
  }
}

resource "aws_iam_role_policy" "efs_orchestrator_lambda_policy" {
  name = "${var.project_name}-orchestrator-lambda-policy"
  role = aws_iam_role.efs_orchestrator_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          var.s3_bucket_arn,
          var.s3_bucket_wildcard_arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "backup:StartRestoreJob",
          "backup:DescribeRestoreJob",
          "backup:ListRecoveryPointsByBackupVault",
          "backup:GetRecoveryPointRestoreMetadata"
        ],
        Resource = "*" # AWS Backup actions often require broad permissions
      },
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:CreateFileSystem",
          "elasticfilesystem:DeleteFileSystem",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:CreateMountTarget",
          "elasticfilesystem:DeleteMountTarget",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeMountTargetSecurityGroups",
          "elasticfilesystem:CreateAccessPoint", # Required for Fargate EFS integration
          "elasticfilesystem:DeleteAccessPoint",
          "elasticfilesystem:DescribeAccessPoints"
        ],
        Resource = "*" # EFS actions often require broad permissions for orchestration
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*" # Broad for simplicity, refine as needed
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ],
        Resource = "*" # ECS actions often require broad permissions for orchestration
      }
    ]
  })
}