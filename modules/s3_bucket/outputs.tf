# Outputs for the S3 bucket module.

output "s3_bucket_name" {
  description = "The name of the S3 bucket."
  value       = aws_s3_bucket.efs_manifests.bucket
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.efs_manifests.arn
}