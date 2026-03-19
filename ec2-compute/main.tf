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

resource "null_resource" "ansible_windows" {
  depends_on = [
    aws_instance.win_srv,
    null_resource.ansible_inventory
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      until nc -w 5 -z ${aws_instance.win_srv.private_ip} 5986; do
        echo "Waiting for WinRM..."; sleep 10
      done && \
      ansible-playbook playbooks/domain_join.yml \
        -i inventory/hosts.ini \
        -l ${aws_instance.win_srv.private_ip} \
        -e "dc_ip=${var.dc_ip}" \
        -e "sid500_password=${random_password.win_admin.result}"
        -e "domain_username=${data.conjur_secret.domain_username.value}" \
        -e "domain_password=${data.conjur_secret.domain_password.value}"
    EOT
  }
}

resource "null_resource" "ansible_unix" {
  depends_on = [
    aws_instance.unix_srv,
    null_resource.ansible_inventory
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      until nc -w 5 -z ${aws_instance.unix_srv.private_ip} 22; do
        echo "Waiting for SSH..."; sleep 10
      done && \
      ansible-playbook playbooks/linux_keypair.yml \
        -i inventory/hosts.ini \
        -l ${aws_instance.unix_srv.private_ip}
    EOT
  }
}

# Windows Server EC2 Instance
resource "aws_instance" "win_srv" {
  ami                    = var.windows_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.win_sg_id
  key_name               = var.aws_key_pair_name
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
  tags = {
    Name = var.unix_instance_name
  }
  
}

# Generate the hosts.ini file for Ansible
resource "null_resource" "ansible_inventory" {
  triggers = {
    win_ip  = aws_instance.win_srv.private_ip
    unix_ip = aws_instance.unix_srv.private_ip
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat > ${path.module}/inventory/hosts.ini <<EOF
      [win_srv]
      ${aws_instance.win_srv.private_ip}

      [linux_srv]
      ${aws_instance.unix_srv.private_ip}

      [win_srv:vars]
      ansible_connection=winrm
      ansible_winrm_transport=ntlm
      ansible_winrm_port=5986
      ansible_winrm_scheme=https
      ansible_winrm_server_cert_validation=ignore

      [linux_srv:vars]
      ansible_connection=ssh
      ansible_user=ec2-user
      ansible_ssh_private_key_file=~/.ssh/your-key.pem
      EOF
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

  depends_on = [ aws_instance.win_srv ]
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

  depends_on = [ aws_instance.unix_srv ]
}