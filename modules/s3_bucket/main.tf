# Manages the S3 bucket for EFS manifests.
# This module creates an S3 bucket with versioning and server-side encryption enabled.
# It also sets the ACL to private and applies necessary tags.

resource "aws_s3_bucket" "efs_manifests" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "${var.project_name}-manifests"
    Environment = "production"
  }
}

resource "aws_s3_bucket_acl" "efs_manifests_acl" {
  bucket = aws_s3_bucket.efs_manifests.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "efs_manifests_versioning" {
  bucket = aws_s3_bucket.efs_manifests.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "efs_manifests_encryption" {
  bucket = aws_s3_bucket.efs_manifests.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Or "aws:kms" if you want to use KMS
    }
  }
}