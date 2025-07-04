# Manages the ECS cluster, EFS access point, and task definition for manifest generation.

# ECS Cluster
resource "aws_ecs_cluster" "efs_manifest_cluster" {
  name = "${var.project_name}-manifest-cluster"

  tags = {
    Name = "${var.project_name}-manifest-cluster"
  }
}

# EFS Access Point for Original Manifest Generation (if needed for a scheduled task)
# This access point is for the *original* EFS, used by a scheduled ECS task
# to generate the 'ground truth' manifest.
resource "aws_efs_access_point" "original_efs_access_point" {
  file_system_id = var.efs_id
  posix_user {
    uid = 0
    gid = 0
  }
  root_directory {
    path = "/"
  }

  tags = {
    Name        = "${var.project_name}-original-ap"
    Environment = "production"
  }
}

# ECS Task Definition for Manifest Generation
resource "aws_ecs_task_definition" "efs_manifest_task" {
  family                   = "${var.project_name}-manifest-task"
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-manifest-container",
      image     = var.ecr_image_uri,
      cpu       = 256,
      memory    = 512,
      essential = true,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/efs-manifest-generator",
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      },
      mountPoints = [
        {
          sourceVolume  = "efs-volume",
          containerPath = "/mnt/efs"
        }
      ],
      environment = [
        {
          name  = "S3_BUCKET_NAME",
          value = var.s3_bucket_name
        },
        {
          name  = "EFS_ID",
          value = var.efs_id
        }
        # Other environment variables can be passed here if needed by the script
      ]
    }
  ])

  volume {
    name = "efs-volume"
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.original_efs_access_point.id # Use the original EFS AP
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-manifest-task-def"
  }
}

# CloudWatch Log Group for ECS Fargate Task Logs
resource "aws_cloudwatch_log_group" "ecs_manifest_log_group" {
  name              = "/ecs/efs-manifest-generator"
  retention_in_days = 30 # Adjust retention as needed

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# Optional: CloudWatch Event Rule to run the original manifest generation task on a schedule
# This replaces the EC2 instance for original manifest generation.
resource "aws_cloudwatch_event_rule" "original_manifest_schedule_rule" {
  name                = "${var.project_name}-original-manifest-schedule"
  description         = "Schedule to run ECS task for original EFS manifest generation."
  schedule_expression = "cron(0 0 * * ? *)" # Runs daily at midnight UTC (adjust as needed)

  tags = {
    Name = "${var.project_name}-original-manifest-schedule"
  }
}

resource "aws_cloudwatch_event_target" "original_manifest_schedule_target" {
  rule      = aws_cloudwatch_event_rule.original_manifest_schedule_rule.name
  target_id = "RunOriginalManifestTask"
  arn       = aws_ecs_cluster.efs_manifest_cluster.arn
  role_arn  = var.ecs_task_execution_role_arn # ECS execution role

  ecs_target {
    launch_type         = "FARGATE"
    platform_version    = "LATEST"
    task_definition_arn = aws_ecs_task_definition.efs_manifest_task.arn
    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = false
    }
  }

  # Pass command line arguments to the container
  input = jsonencode({
    containerOverrides = [
      {
        name = "${var.project_name}-manifest-container",
        command = [
          "python3",
          "/path/to/your/script.py", # Adjust to your script path
          "--s3-bucket-name", var.s3_bucket_name,
          "--efs-id", var.efs_id
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_events_invoke_task_policy" {
  name = "${var.project_name}-ecs-events-invoke-task-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ecs:RunTask",
        Resource = aws_ecs_task_definition.efs_manifest_task.arn
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          var.ecs_task_execution_role_arn,
          var.ecs_task_role_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_events_invoke_task_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name # Attach to the execution role or a dedicated events role
  policy_arn = aws_iam_policy.ecs_events_invoke_task_policy.arn
}