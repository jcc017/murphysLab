resource "aws_s3_bucket" "s3_state_bucket" {
    bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_versioning" "s3_bucket_version" {
    bucket = aws_s3_bucket.s3_state_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_public_access_block" "s3_pub_access_block" {
    bucket = aws_s3_bucket.s3_state_bucket.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}