# Conjur Secrets
data "conjur_secret" "aws_access_key" {
  name = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  name = var.conjur_aws_secret_key_path
}

resource "aws_s3_bucket" "s3_bucket" {
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

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
    bucket = aws_s3_bucket.s3_bucket.id

    policy = jsonencode({
        Version = "2012=10-17"
        Statement = [
            {
                Sid = "AllowViaVPCEndpoint"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:*"
                Resource = [
                    aws_s3_bucket.s3_bucket.arn,
                    "${aws_s3_bucket.s3_bucket.arn}/*"
                ]
                Condition = {
                    StringEquals = {
                        "aws:sourceVpce" = var.s3_vpc_endpoint_id
                    }
                }
            },
            {
                Sid = "AllowViaIP"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:*"
                Resource = [
                   aws_s3_bucket.s3_bucket.arn,
                    "${aws_s3_bucket.s3_bucket.arn}/*" 
                ]
                Condition = {
                    IpAddress = {
                        "aws:SourceIp" = var.allowed_ips
                    }
                }
            }
        ]
    })
}