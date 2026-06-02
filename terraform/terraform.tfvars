project_name   = "travelmemory"
environment    = "production"
aws_region     = "us-east-1"
instance_type  = "t2.micro"

# REPLACE these with your actual details:
# The IP allowed to SSH into the web server. E.g., "203.0.113.50/32".
allowed_ssh_ip = "0.0.0.0/0" 

# Replace with your actual SSH public key content (e.g. from ~/.ssh/id_rsa.pub)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDxm2hV8v1D5R1v8L6+gq6uK2T7gWJk+q10/D0fUe+x/rWfQ== user@localhost"
