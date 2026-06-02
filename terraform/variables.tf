variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "travelmemory"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "Target AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"
}

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 LTS AMI for us-east-1"
  type        = string
  default     = "ami-080e1f13689e07408" # standard Ubuntu 22.04 LTS x86_64 in us-east-1
}

variable "allowed_ssh_ip" {
  description = "IP address allowed to connect via SSH to the public instance"
  type        = string
  default     = "0.0.0.0/0" # Should be set to user's specific IP in production (e.g. 203.0.113.50/32)
}

variable "ssh_public_key" {
  description = "SSH public key content to authorize on instances"
  type        = string
  # A dummy key is provided as a placeholder. The user should replace it with their actual public key content.
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDxm2hV8v1D5R1v8L6+gq6uK2T7gWJk+q10/D0fUe+x/rWfQ== user@localhost"
}
