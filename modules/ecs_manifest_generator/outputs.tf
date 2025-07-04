# Outputs for the ECS manifest generator module.

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.efs_manifest_cluster.name
}

output "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition."
  value       = aws_ecs_task_definition.efs_manifest_task.arn
}

output "ecs_container_name" {
  description = "The name of the container within the ECS task definition."
  value       = "${var.project_name}-manifest-container"
}

output "original_efs_access_point_id" {
  description = "The ID of the EFS Access Point for the original EFS."
  value       = aws_efs_access_point.original_efs_access_point.id
}