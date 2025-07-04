# Variables for the S3 bucket module.

variable "project_name" {
  description = "A unique name for the project."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name for the S3 bucket to store EFS manifests. Must be globally unique."
  type        = string
}