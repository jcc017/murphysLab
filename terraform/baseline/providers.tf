provider "aws" {
  region = var.aws_region
  access_key = data.conjur_secret.aws_access_key.value
  secret_key = data.conjur_secret.aws_secret_key.value
}