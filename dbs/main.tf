data "conjur_secret" "aws_access_key" {
  name = var.conjur_aws_access_key_id
}

data "conjur_secret" "aws_secret_key" {
  name = var.conjur_aws_secret_key
}

data "conjur_secret" "ispss_username" {
  name = var.conjur_api_username_path
}

data "conjur_secret" "ispss_password" {
  name = var.conjur_api_password_path
}

#data "idsec_cmgr_network" "cybr_cm_network" {
  #name = var.cybr_cm_network
#}

#data "idsec_cmgr_pool" "cybr_cm_pool" {
  #name = var.cybr_cm_pool
#}

#data "idsec_sia_access_connector" "cybr_connector" {
  #name = var.cybr_connector_name
#}

resource "random_password" "postgres" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "mssql" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "aws_db_instance" "postgres_db" {
    identifier = var.postgres_instance_name
    engine = "postgres"
    engine_version = "16.3"
    instance_class = var.db_instance_class
    db_name = var.postgres_db_name
    username = var.postgres_master_username
    password= random_password.postgres.result
    db_subnet_group_name = var.db_subnet_group_name
    vpc_security_group_ids = var.postgres_sg_id
    skip_final_snapshot = true
    tags = {
        Name = var.postgres_instance_name
    }

}

resource "aws_security_group" "mssql_sg" {
  name        = "mssql-sg-${var.mssql_instance_name}"
  description = "Security group for MSSQL RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "MSSQL port"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = var.mssql_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mssql-sg-${var.mssql_instance_name}"
  }
}

resource "aws_db_instance" "mssql_db" {
    identifier = var.mssql_instance_name
    engine         = "sqlserver-ex"
    engine_version = "15.00.4355.3.v1" 
    instance_class = var.db_instance_class
    license_model = "license-included"
    username = var.mssql_master_username
    password= random_password.mssql.result
    db_subnet_group_name = var.db_subnet_group_name
    vpc_security_group_ids = [aws_security_group.mssql_sg.id]
    skip_final_snapshot = true
    tags = {
        Name = var.mssql_instance_name
    }
    depends_on = [ aws_security_group.mssql_sg ]
}

resource  "cyberark_db_account" "postgres_db" {
  name                        = "${var.postgres_master_username}-${var.postgres_hostname}"
  address                     = aws_db_instance.postgres_db.address
  username                    = var.postgres_master_username
  platform                    = var.postgres_platform_id
  safe                        = var.postgres_target_safe
  secret                      = random_password.postgres.result
  secret_name_in_secret_store = var.postgres_master_username
  sm_manage                   = true
  sm_manage_reason            = "All master accounts should be managed"
  db_port                     = var.postgres_db_port
  db_dsn                      = aws_db_instance.postgres_db.address
  dbname                      = var.postgres_db_name
  depends_on                  = [aws_db_instance.postgres_db]
}

resource  "cyberark_db_account" "mssql_db" {
  name                        = "${var.mssql_master_username}-${var.mssql_hostname}"
  address                     = aws_db_instance.mssql_db.address
  username                    = var.mssql_master_username
  platform                    = var.mssql_platform_id
  safe                        = var.mssql_target_safe
  secret                      = random_password.mssql.result
  secret_name_in_secret_store = var.mssql_master_username
  sm_manage                   = true
  sm_manage_reason            = "All master accounts should be managed"
  db_port                     = var.mssql_db_port
  db_dsn                      = aws_db_instance.mssql_db.address
  dbname                      = var.mssql_db_name
  depends_on                  = [aws_db_instance.mssql_db]
}

resource "idsec_sia_db_strong_accounts" "postgres_strong_account" {
  name         = "${var.postgres_master_username}-${var.postgres_hostname}"
  store_type   = "pam"
  account_name = "${var.postgres_master_username}-${var.postgres_hostname}"
  safe         = var.postgres_target_safe
  depends_on   = [cyberark_db_account.postgres_db]
}

resource "idsec_sia_db_strong_accounts" "mssql_strong_account" {
  name         = "${var.mssql_master_username}-${var.mssql_hostname}"
  store_type   = "pam"
  account_name = "${var.mssql_master_username}-${var.mssql_hostname}"
  safe         = var.mssql_target_safe
  depends_on   = [cyberark_db_account.mssql_db]
}

resource "idsec_sia_workspaces_db" "postgres_db" {
  name                        = var.postgres_hostname
  read_write_endpoint         = aws_db_instance.postgres_db.address
  configured_auth_method_type = "local"
  port                        = var.postgres_db_port
  secret_id                   = idsec_sia_db_strong_accounts.postgres_strong_account.account_id
  family                      = "postgresql"
  platform                    = "AWS"
  region                      = var.aws_region
  depends_on                  = [idsec_sia_db_strong_accounts.postgres_strong_account]
}

resource "idsec_sia_workspaces_db" "mssql_db" {
  name                        = var.mssql_hostname
  read_write_endpoint         = aws_db_instance.mssql_db.address
  configured_auth_method_type = "local"
  port                        = var.mssql_db_port
  secret_id                   = idsec_sia_db_strong_accounts.mssql_strong_account.account_id
  family                      = "mssql"
  platform                    = "AWS"
  region                      = var.aws_region
  depends_on                  = [idsec_sia_db_strong_accounts.mssql_strong_account]
}
