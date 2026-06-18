# Conjur Secrets
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

# Generate SID 500 Password
resource "random_password" "win_admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2

  lifecycle {
    ignore_changes = all
  }
}

# Dynamic AMI lookups for EC2 instances
data "aws_ami" "windows" {
  most_recent = true
  owners = ["amazon"]
   
   filter {
     name = "name"
     values = ["Windows_Server-2022-English-Full-Base-*"]
   }

   filter {
     name = "virtualization-type"
     values = ["hvm"]
   }
}

data "aws_ami" "unix" {
  most_recent = true
  owners = ["amazon"]
   
   filter {
     name = "name"
     values = ["al2023-ami-*-x86_64"]
   }

   filter {
     name = "virtualization-type"
     values = ["hvm"]
   }
}

# Create an inventory to be used by Ansible
resource "local_file" "ansible_inventory" {
  filename = "${var.ansible_root}/inventory/hosts.ini"
  content  = templatefile("${path.module}/templates/hosts.ini.tpl", {
    win_hostname    = var.win_hostname
    win_private_ip  = aws_instance.win_srv.private_ip
    unix_hostname   = var.unix_hostname
    unix_private_ip = aws_instance.unix_srv.private_ip
  })
}

# Windows Server EC2 Instance
resource "aws_instance" "win_srv" {
  ami                    = data.aws_ami.windows.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.win_sg_id
  key_name               = var.aws_key_pair_name
  iam_instance_profile   = var.iam_instance_profile

  user_data = <<-EOF
    <powershell>
    Set-LocalUser -Name "Administrator" -Password (ConvertTo-SecureString "${random_password.win_admin.result}" -AsPlainText -Force)
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
    Enable-PSRemoting -Force
    </powershell>
  EOF

  tags = {
    Name = var.win_instance_name
    I_Purpose = var.win_purpose_tag
    CA_iScheudler = var.CA_iScheudler_tag
    I_Owner = var.resource_owner_tag
  }

  lifecycle {
    ignore_changes = [ ami,user_data ]
  }
}

# Unix Server EC2 Instance
resource "aws_instance" "unix_srv" {
  ami                    = data.aws_ami.unix.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.unix_sg_id
  key_name               = var.aws_key_pair_name
  iam_instance_profile   = var.iam_instance_profile

  tags = {
    Name = var.unix_instance_name
    I_Purpose = var.unix_purpose_tag
    CA_iScheudler = var.CA_iScheudler_tag
    I_Owner = var.resource_owner_tag
  }

  lifecycle {
    ignore_changes = [ ami ]
  }
}

#Ansible configuration for the Windows Server
resource "terraform_data" "ansible_windows" {
  
  triggers_replace = {
    instance_id     = aws_instance.win_srv.id
    instance_ip     = aws_instance.win_srv.private_ip
    sid500_password = random_password.win_admin.result
    domain_username = data.conjur_secret.domain_username.value
    domain_name     = var.domain_name
    dc_ip           = var.dc_ip
    win_hostname    = var.win_hostname
    ansible_root    = var.ansible_root
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    # Write creds to a temp vars file so never visible
    # file and deleted immediately after the playbook completes/fails
    
    command = <<-EOT
      export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

      VARS_FILE=$(mktemp /tmp/ansible_vars_XXXXXX.yml)
      trap "rm -f $VARS_FILE" EXIT

      cat > "$VARS_FILE" <<VARS
      domain_username: '${data.conjur_secret.domain_username.value}'
      domain_password: '${base64encode(data.conjur_secret.domain_password.value)}'
      sid500_password: '${random_password.win_admin.result}'
      VARS
      chmod 600 "$VARS_FILE"

      echo "Waiting for WinRM to become available"
      ansible all -m wait_for_connection \
        -a "timeout=600 delay=60" \
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${var.win_hostname} \
        -e "@$VARS_FILE"

      echo "Running domain join playbook via WinRM..."
      ansible-playbook ${var.ansible_root}/playbooks/domain_join.yml \
       -i ${var.ansible_root}/inventory/hosts.ini \
       -l ${var.win_hostname} \
       -e "dc_ip=${var.dc_ip}" \
       -e "domain_name=${var.domain_name}" \
       -e "@$VARS_FILE"
    EOT
  }

  depends_on = [ 
    aws_instance.win_srv, 
    local_file.ansible_inventory
  ]
}

#Ansible configuration for the Unix server
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "terraform_data" "ansible_unix" {
  triggers_replace = {
    instance_id = aws_instance.unix_srv.id
    instance_ip = aws_instance.unix_srv.private_ip
    unix_hostname = var.unix_hostname
    ansible_root = var.ansible_root
  }

  input = aws_instance.unix_srv.id

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command     = <<-EOT
      export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

      PEM_FILE=$(mktemp /tmp/ssh_key_XXXXXX.pem)
      trap "rm -f $PEM_FILE" EXIT
      echo '${data.conjur_secret.pem_key.value}' > "$PEM_FILE"
      chmod 600 "$PEM_FILE"

      echo "Waiting for SSH to become available"
      ansible all -m wait_for_connection \
        -a "timeout=600 delay=60" \
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${var.unix_hostname} \
        --private-key "$PEM_FILE" 
      sleep 30
      echo "Running keypair playbook via SSH..."
      ansible-playbook ${var.ansible_root}/playbooks/linux_keypair.yml \
        -i ${var.ansible_root}/inventory/hosts.ini \
        -l ${var.unix_hostname} \
        -e "new_public_key='${trimspace(tls_private_key.generated_key.public_key_openssh)}'"\
        --private-key "$PEM_FILE" 
    EOT
  }

  depends_on = [
    aws_instance.unix_srv,
    local_file.ansible_inventory
  ]
}

# CyberArk Automation - Account Onboarding and SIA Policy Creation
resource "idsec_pcloud_account" "win_srv_admin" {
  name        = "Administrator-${var.win_hostname}"
  platform_id = var.win_platform_id
  username    = "Administrator"
  address     = "${var.win_hostname}.${var.domain_name}"
  secret_type = "password"
  secret      = random_password.win_admin.result
  safe_name   = var.win_target_safe
  automatic_management_enabled = true

  depends_on = [
    aws_instance.win_srv,
    terraform_data.ansible_windows
  ]
}

resource "idsec_pcloud_account" "ec2-user" {
  name        = "ec2-user-${var.unix_hostname}"
  platform_id = var.unix_platform_id
  username    = "ec2-user"
  address     = aws_instance.unix_srv.private_ip
  secret_type = "key"
  secret      = tls_private_key.generated_key.private_key_pem
  safe_name   = var.unix_target_safe
  automatic_management_enabled = true

  depends_on = [
    aws_instance.unix_srv,
    terraform_data.ansible_unix
  ]
}
