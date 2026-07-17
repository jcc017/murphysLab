output "s3_bucket_identifier" {
  description = "Identifier of S3 bucket"
  value       = aws_s3_bucket.s3_state_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of S3 bucket"
  value = aws_s3_bucket.s3_state_bucket.arn
}