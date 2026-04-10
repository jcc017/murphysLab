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
resource "null_resource" "cybr_automation" {
  depends_on = [
  null_resource.ansible_windows,
  null_resource.ansible_unix,
  random_password.win_admin

  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
   

      # Step 1 - Get bearer token from ISPSS platformtoken endpoint
        ISPSS_USERNAME="${data.conjur_secret.ispss_username.value}"
        ISPSS_PASSWORD="${data.conjur_secret.ispss_password.value}"

        TOKEN=$(curl -s -X POST \
        "https://${var.identity_tenant_id}.id.cyberark.cloud/oauth2/platformtoken" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$ISPSS_USERNAME&client_secret=$ISPSS_PASSWORD" \
        | jq -r '.access_token')

      # Step 2 - Onboard Windows Administrator account to Privilege Cloud
        WIN_ACCOUNT_PAYLOAD=$(jq -n \
            --arg name "Administrator-${var.win_hostname}" \
            --arg address "${aws_instance.win_srv.private_ip}" \
            --arg platformId "${var.win_platform_id}" \
            --arg safeName "${var.win_target_safe}" \
            --arg secret "${random_password.win_admin.result}" \
            '{
            name: $name,
            address: $address,
            userName: "Administrator",
            platformId: $platformId,
            safeName: $safeName,
            secretType: "password",
            secret: $secret,
            secretManagement: {
                automaticManagementEnabled: true
            }
            }')

        WIN_ACCOUNT_ID=$(curl -s -X POST \
            "https://${var.cybr_subdomain}.privilegecloud.cyberark.cloud/PasswordVault/API/Accounts/" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$WIN_ACCOUNT_PAYLOAD" \
            | jq -r '.id')


      # Step 3 - Onboard Unix ec2-user account with private key

        PEM_KEY="${data.conjur_secret.pem_key.value}"

        UNIX_ACCOUNT_PAYLOAD=$(jq -n \
            --arg name "ec2-user-${var.unix_hostname}" \
            --arg address "${aws_instance.unix_srv.private_ip}" \
            --arg platformId "${var.unix_platform_id}" \
            --arg safeName "${var.unix_target_safe}" \
            --arg secret "$PEM_KEY" \
            '{
            name: $name,
            address: $address,
            userName: "ec2-user",
            platformId: $platformId,
            safeName: $safeName,
            secretType: "key",
            secret: $secret,
            secretManagement: {
                automaticManagementEnabled: true
            }
            }')

        UNIX_ACCOUNT_ID=$(curl -s -X POST \
            "https://${var.cybr_subdomain}.privilegecloud.cyberark.cloud/PasswordVault/API/Accounts/" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UNIX_ACCOUNT_PAYLOAD" \
            | jq -r '.id')

      # Step 4 - Retrieve Safe members for both target Safes
        WIN_MEMBERS=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.privilegecloud.cyberark.cloud/PasswordVault/API/Safes/${var.win_target_safe}/Members/" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '[.value[] | select(.isPredefinedUser == false) | {name: .memberName, type: .memberType}]')

        UNIX_MEMBERS=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.privilegecloud.cyberark.cloud/PasswordVault/API/Safes/${var.unix_target_safe}/Members/" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '[.value[] | select(.isPredefinedUser == false) | {name: .memberName, type: .memberType}]')

      # Step 5 - SIA policy pre-checks
        WIN_FQDN_CHECK=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies?filter=(fqdns contains '${var.win_hostname}.${var.domain_name}')" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '.total')

        WIN_WILDCARD_CHECK=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies?filter=(fqdns contains '*.${var.domain_name}')" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '.total')

        WIN_VPC_CHECK=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies?filter=(platforms contains 'AWS')" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '[.items[] | select(.rules[].assets[]?.id == "${aws_instance.win_srv.private_ip}")] | length')

        UNIX_FQDN_CHECK=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies?filter=(fqdns contains '${var.unix_hostname}.${var.domain_name}')" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '.total')

        UNIX_WILDCARD_CHECK=$WIN_WILDCARD_CHECK

        UNIX_VPC_CHECK=$(curl -s -X GET \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies?filter=(platforms contains 'AWS')" \
            -H "Authorization: Bearer $TOKEN" \
            | jq '[.items[] | select(.rules[].assets[]?.id == "${aws_instance.unix_srv.private_ip}")] | length')

      # Step 6 - Split Safe members into users and groups
        WIN_USERS=$(echo $WIN_MEMBERS | jq '[.[] | select(.type == "User") | {name: .name}]')
        WIN_GROUPS=$(echo $WIN_MEMBERS | jq '[.[] | select(.type == "Group") | {name: .name}]')
        UNIX_USERS=$(echo $UNIX_MEMBERS | jq '[.[] | select(.type == "User") | {name: .name}]')
        UNIX_GROUPS=$(echo $UNIX_MEMBERS | jq '[.[] | select(.type == "Group") | {name: .name}]')

      # Step 7 - Create SIA policies if no existing policy found
        if [ "$WIN_FQDN_CHECK" -eq 0 ] && [ "$WIN_WILDCARD_CHECK" -eq 0 ] && [ "$WIN_VPC_CHECK" -eq 0 ]; then
            WIN_POLICY_PAYLOAD=$(jq -n \
            --arg policyName "TerraformWindows-${var.win_hostname}" \
            --arg region "${var.aws_region}" \
            --arg vpc "${var.vpc_id}" \
            --arg account "${var.aws_account_id}" \
            --argjson users "$WIN_USERS" \
            --argjson groups "$WIN_GROUPS" \
            '{
                policyName: $policyName,
                status: "Enabled",
                policyType: "VM",
                providersData: {
                AWS: {
                    providerName: "AWS",
                    regions: [$region],
                    vpcIds: [$vpc],
                    accountIds: [$account],
                    tags: []
                }
                },
                userAccessRules: [{
                ruleName: "TerraformWindows-Access",
                connectionInformation: {
                    connectAs: {
                    AWS: {
                        rdp: {
                        localEphemeralUser: {
                            assignGroups: ["Administrators"]
                        }
                        }
                    }
                    },
                    daysOfWeek: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],
                    fullDays: true,
                    grantAccess: 24,
                    timeZone: "US/Eastern"
                },
                userData: {
                    users: $users,
                    groups: $groups,
                    roles: []
                }
                }]
            }')

            WIN_POLICY_ID=$(curl -s -X POST \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$WIN_POLICY_PAYLOAD" \
            | jq -r '.policyId')
        fi

        if [ "$UNIX_FQDN_CHECK" -eq 0 ] && [ "$UNIX_WILDCARD_CHECK" -eq 0 ] && [ "$UNIX_VPC_CHECK" -eq 0 ]; then
            UNIX_POLICY_PAYLOAD=$(jq -n \
            --arg policyName "TerraformUnix-${var.unix_hostname}" \
            --arg region "${var.aws_region}" \
            --arg vpc "${var.vpc_id}" \
            --arg account "${var.aws_account_id}" \
            --argjson users "$UNIX_USERS" \
            --argjson groups "$UNIX_GROUPS" \
            '{
                policyName: $policyName,
                status: "Enabled",
                policyType: "VM",
                providersData: {
                AWS: {
                    providerName: "AWS",
                    regions: [$region],
                    vpcIds: [$vpc],
                    accountIds: [$account],
                    tags: []
                }
                },
                userAccessRules: [{
                ruleName: "TerraformUnix-Access",
                connectionInformation: {
                    connectAs: {
                    AWS: {
                        ssh: "ec2-user"
                    }
                    },
                    daysOfWeek: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],
                    fullDays: true,
                    grantAccess: 24,
                    timeZone: "US/Eastern"
                },
                userData: {
                    users: $users,
                    groups: $groups,
                    roles: []
                }
                }]
            }')

            UNIX_POLICY_ID=$(curl -s -X POST \
            "https://${var.cybr_subdomain}.dpa.cyberark.cloud/api/access-policies" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$UNIX_POLICY_PAYLOAD" \
            | jq -r '.policyId')
        fi
    EOT
  }
}
