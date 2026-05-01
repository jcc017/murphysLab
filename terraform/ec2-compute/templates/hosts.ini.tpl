[win_srv]
${win_id}

[linux_srv]
${unix_id} 

[all_srv:children]
win_srv
linux_srv

# Shared variables
[all_srv:vars]
ansible_connection=aws_ssm
ansible_aws_ssm_region=us-east-2
ansible_aws_ssm_bucket_name=${s3_bucket}

#Windows exclusive variables
[win_srv:vars]
ansible_shell_type=powershell
ansible_user=Administrator

#Linux exclusive variables
[linux_srv:vars]
ansible_user=ec2-user