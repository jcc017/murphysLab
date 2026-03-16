terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    conjur = {
      source  = "cyberark/conjur"
      version = "~> 0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  access_key = data.conjur_secret.aws_access_key.value
  secret_key = data.conjur_secret.aws_secret_key.value
}

#provider "idsec" {
  # Configuration options
#}

#provider "cyberark" {
  # Configuration options
#}

provider "conjur" {
  appliance_url = var.conjur_url
  account       = var.conjur_account
  login         = var.conjur_login
  api_key       = var.conjur_api_key
}
