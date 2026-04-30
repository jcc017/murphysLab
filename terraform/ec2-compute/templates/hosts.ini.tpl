[win_srv]
${win_ip} ansible_connection=aws_ssm ansible_shell_type=powershell

[linux_srv]
${unix_ip} ansible_connection=aws_ssm

[all_srv:children]
win_srv
linux_srv

[win_srv:vars]
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_port=5986
ansible_user=Administrator

[linux_srv:vars]
ansible_connection=ssh
ansible_user=ec2-user