# RDS Instance Configuration
variable "db_instance_class" {
  description = "RDS instance class for both databases"
  type        = string
}

variable "postgres_db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
}

variable "mssql_db_name" {
  description = "Name of the MSSQL database"
  type        = string
}

variable "postgres_db_port" {
  description = "Port for PostgreSQL database"
  type        = number
  default     = 5432
}

variable "mssql_db_port" {
  description = "Port for MSSQL database"
  type        = number
  default     = 1433
}

variable "postgres_hostname" {
  description = "Friendly name for PostgreSQL instance used in CyberArk account naming"
  type        = string
}

variable "mssql_hostname" {
  description = "Friendly name for MSSQL instance used in CyberArk account naming"
  type        = string
}

# Networking
variable "aws_account_id" {
  description = "Account ID for AWS environment"
  type        = string
}

variable "aws_region" {
  description = "Region in AWS"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group"
  type        = string
}

variable "vpc_id" {
  description = "ID of VPC for RDS instances"
  type        = string
}

variable "postgres_sg_id" {
  description = "ID(s) of postgres security group(s)"
  type        = list(string)
}

variable "mssql_sg_id" {
  description = "ID(s) of MSSQL security group(s)"
  type        = list(string)
}

variable "postgres_master_username" {
  description = "Master username for PostgreSQL RDS instance"
  type        = string
  default     = "postgres"
}

variable "mssql_master_username" {
  description = "Master username for MSSQL RDS instance"
  type        = string
  default     = "admin"
}

# Server Instance Names
variable "postgres_instance_name" {
  description = "Display name for PostgreSQL RDS instance as shown in AWS console"
  type        = string
}

variable "mssql_instance_name" {
  description = "Display name for MSSQL RDS instance as shown in AWS console"
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


# Conjur Variable Paths - ISPSS API Credential
variable "conjur_api_username_path" {
  description = "Conjur variable path for ISPSS service account username"
  type        = string
}

variable "conjur_api_password_path" {
  description = "Conjur variable path for ISPSS service account password"
  type        = string
}

# Conjur Variable Paths - AWS Access Key
variable "conjur_aws_access_key_id" {
  description = "Conjur variable path for AWS Access Key ID"
  type        = string
}

variable "conjur_aws_secret_key" {
  description = "Conjur variable path for AWS Access Key Secret"
  type        = string
}

# CyberArk Tenant
variable "identity_tenant_id" {
  description = "Identity ID for CyberArk tenant"
  type        = string
}

variable "cybr_subdomain" {
  description = "Subdomain of CyberArk tenant"
  type        = string
}

#CyberArk Connector Management
variable "cybr_cm_network" {
  description = "Connector Mgmt network identifier"
  type        = string
}

variable "cybr_cm_pool" {
  description = "Name of the existing SIA connector manager pool"
  type        = string
}

variable "cybr_connector_name" {
  description = "Name of the existing SIA access connector"
  type        = string
}

# CyberArk Target Safes
variable "postgres_target_safe" {
  description = "Safe where local postgres admin account is stored"
  type        = string
}

variable "mssql_target_safe" {
  description = "Safe where local mssql admin account is stored"
  type        = string
}

# CyberArk Platform IDs
variable "postgres_platform_id" {
  description = "CyberArk platform ID for PostgreSQL database accounts"
  type        = string
}

variable "mssql_platform_id" {
  description = "CyberArk platform ID for MSSQL database accounts"
  type        = string
}
