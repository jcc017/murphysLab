# Networking
variable "aws_region" {
  description = "Region in AWS"
  type        = string
}

# Conjur Variable Paths - AWS Access Key
variable "conjur_aws_access_key_path" {
  description = "Conjur variable path for AWS Access Key ID"
  type        = string
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur variable path for AWS Secret Access Key"
  type        = string
}

#Conjur AuthN
variable "conjur_url" {
  description = "Conjur Cloud appliance URL including /api"
  type        = string
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
}

variable "conjur_login" {
  description = "Conjur host login path e.g. host/data/workload-id"
  type        = string
}

variable "conjur_api_key" {
  description = "API key for Terraform executor host identity in Conjur"
  type        = string
  sensitive   = true
}

#S3 Bucket Vars
variable "s3_bucket_name" {
    description = "s3 bucket for storing the state files for the terraform plan"
    type = string
}

variable "s3_vpc_endpoint_id" {
    description = "ID of VPC endpoint to allow in the bucket policy"
    type = string
}

variable "allowed_ips" {
    description = "IP range of hosts allowed to access the S3 bucket"
    type = string
}