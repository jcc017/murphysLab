# EC2 Instance Configuration
variable "windows_ami_id" {
  description = "AMI ID for Windows Server 2022"
  type        = string
}

variable "unix_ami_id" {
  description = "AMI ID for AWS Linux"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for both servers"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM profile for the EC2 instances"
  type = string
}

# Networking
variable "aws_region" {
  description = "Region in AWS"
  type        = string
}

variable "subnet_id" {
  description = "ID for the AWS network subnet"
  type        = string
}

variable "win_sg_id" {
  description = "ID(s) of Windows security group(s)"
  type        = list(string)
}

variable "unix_sg_id" {
  description = "ID(s) of Unix security group(s)"
  type        = list(string)
}

variable "aws_key_pair_name" {
  description = "Name of the existing AWS EC2 key pair to assign to instances"
  type        = string
}

# Server Hostnames
variable "win_hostname" {
  description = "Hostname of Windows Server"
  type        = string
}

variable "unix_hostname" {
  description = "Hostname of Unix Server"
  type        = string
}

# Ansible Variables
variable "ansible_root" {
  description = "Absolute path to the ansible directory"
  type        = string
  
}

# Server Instance Names
variable "win_instance_name" {
  description = "Display name for Windows EC2 instance as shown in AWS console"
  type        = string
}

variable "unix_instance_name" {
  description = "Display name for Unix EC2 instance as shown in AWS console"
  type        = string
}

# Active Directory
variable "domain_name" {
  description = "AD domain to join server"
  type        = string
}

variable "dc_ip" {
  description = "IP address of Domain Controller for domain joining"
  type = string
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

# Conjur Variable Paths - Domain Join Credential
variable "conjur_domain_username_path" {
  description = "Conjur variable path for domain join username"
  type        = string
}

variable "conjur_domain_password_path" {
  description = "Conjur variable path for domain join password"
  type        = string
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
variable "conjur_aws_access_key_path" {
  description = "Conjur variable path for AWS Access Key ID"
  type        = string
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur variable path for AWS Secret Access Key"
  type        = string
}

#Conjur Variable Path - AWS PEM key
variable "conjur_pem_key_path" {
  description = "Conjur variable path for .pem key to access new instances"
  type        = string
}

# CyberArk Target Safes
variable "win_target_safe" {
  description = "Safe where local Windows admin account is stored"
  type        = string
}

variable "unix_target_safe" {
  description = "Safe where root account is stored"
  type        = string
}

# CyberArk Platform IDs
variable "win_platform_id" {
  description = "ID for the Windows Local Admin platform"
  type        = string
}

variable "unix_platform_id" {
  description = "ID for the platform that manages the ec2-user account"
  type        = string
}
