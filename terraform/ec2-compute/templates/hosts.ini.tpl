[win_srv]
${win_private_ip} ansible_host=${win_private_ip}

[linux_srv]
${unix_private_ip} ansible_host=${unix_private_ip}

[all_srv:children]
win_srv
linux_srv

#Windows exclusive variables
[win_srv:vars]
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_port=5985
ansible_winrm_scheme=http

#Linux exclusive variables
[linux_srv:vars]
ansible_connection=ssh
ansible_user=ec2-user

