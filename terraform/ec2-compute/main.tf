data "conjur_secret" "aws_access_key" {
  name = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  name = var.conjur_aws_secret_key_path
}

data "conjur_secret" "domain_username" {
  name = var.conjur_domain_username_path
}

data "conjur_secret" "domain_password" {
  name = var.conjur_domain_password_path
}

data "conjur_secret" "ispss_username" {
  name = var.conjur_api_username_path
}

data "conjur_secret" "ispss_password" {
  name = var.conjur_api_password_path
}

data "conjur_secret" "pem_key" {
  name = var.conjur_pem_key_path
}

resource "random_password" "win_admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Use local_file + templatefile to ensures hosts.ini has no leading whitespace that breaks Ansible INI parsing.
resource "local_file" "ansible_inventory" {
  filename = "${var.ansible_root}/inventory/hosts.ini"
  content  = templatefile("${path.module}/templates/hosts.ini.tpl", {
    win_ip  = aws_instance.win_srv.id
    unix_ip = aws_instance.unix_srv.id
  })
}

# Windows Server EC2 Instance
resource "aws_instance" "win_srv" {
  ami                    = var.windows_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.win_sg_id
  key_name               = var.aws_key_pair_name
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name = var.win_instance_name
  }
}

# Unix Server EC2 Instance
resource "aws_instance" "unix_srv" {
  ami                    = var.unix_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.unix_sg_id
  key_name               = var.aws_key_pair_name
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name = var.unix_instance_name
  }
}

resource "null_resource" "ansible_windows" {
  depends_on = [
    aws_instance.win_srv,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    # Write creds to a temp vars file so never visible
    # file and deleted immediately after the playbook completes/fails
    
    command = <<-EOT
      VARS_FILE=$(mktemp /tmp/ansible_vars_XXXXXX.yml)
      trap "rm -f $VARS_FILE" EXIT

      cat > "$VARS_FILE" <<VARS
      domain_username: "${data.conjur_secret.domain_username.value}"
      domain_password: "${data.conjur_secret.domain_password.value}"
      sid500_password: "${random_password.win_admin.result}"
      VARS
      chmod 600 "$VARS_FILE"

      echo "Waiting for Windows to register with AWS SSM..."
      ansible all -m wait_for_connection \
        -a "timeout=300" \
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${aws_instance.win_srv.id} \
        -e "@$VARS_FILE"
      
      echo "Running local admin playbook via SSM..."
      ansible-playbook ${var.ansible_root}/playbooks/win_local_admin.yml \
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${aws_instance.win_srv.id} \
        -e "@$VARS_FILE"

      echo "Running domain join playbook via SSM..."
      ansible-playbook ${var.ansible_root}/playbooks/domain_join.yml \
       -i ${var.ansible_root}/inventory/hosts.ini \
       -l ${aws_instance.win_srv.id} \
       -e "dc_ip=${var.dc_ip}" \
       -e "@$VARS_FILE"
    EOT
  }
}

resource "null_resource" "ansible_unix" {
  depends_on = [
    aws_instance.unix_srv,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Waiting for Unix to register with AWS SSM..."
      ansible all -m wait_for_connection \
        -a "timeout=300"
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${aws_instance.unix_srv.id}

      echo "Running keypair playbook via SSM..."
      ansible-playbook playbooks/linux_keypair.yml \
        -i inventory/hosts.ini \
        -l ${aws_instance.unix_srv.id}
    EOT
  }
}

# CyberArk Automation - Account Onboarding and SIA Policy Creation
resource "idsec_pcloud_account" "win_srv_admin" {
  name        = "Administrator-${var.win_hostname}"
  platform_id = var.win_platform_id
  username    = "Administrator"
  address     = aws_instance.win_srv.private_ip
  secret_type = "password"
  secret      = random_password.win_admin.result
  safe_name   = var.win_target_safe
  automatic_management_enabled = true

  depends_on = [aws_instance.win_srv]
}

resource "idsec_pcloud_account" "ec2-user" {
  name        = "ec2-user-${var.unix_hostname}"
  platform_id = var.unix_platform_id
  username    = "ec2-user"
  address     = aws_instance.unix_srv.private_ip
  secret_type = "key"
  secret      = data.conjur_secret.pem_key.value
  safe_name   = var.unix_target_safe
  automatic_management_enabled = true

  depends_on = [aws_instance.unix_srv]
}
