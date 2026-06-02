# Security Group for the Web Server (Frontend + Backend Proxy)
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security Group for Web Server"
  vpc_id      = aws_vpc.main.id

  # SSH Inbound (Restricted to Developer's IP)
  ingress {
    description = "Allow SSH from Developer IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_ip]
  }

  # HTTP Inbound (Nginx Frontend access)
  ingress {
    description = "Allow HTTP Web Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Inbound (SSL Web Traffic)
  ingress {
    description = "Allow HTTPS Web Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend Inbound (Optional direct backend API communication if needed)
  ingress {
    description = "Allow Backend API direct access"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All Traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
  }
}

# Security Group for the Database Server (MongoDB)
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security Group for Database Server"
  vpc_id      = aws_vpc.main.id

  # MongoDB Inbound (Restricted to Web Server only)
  ingress {
    description     = "Allow MongoDB access from Web Server"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # SSH Inbound from Web Server (Bastion/Jump host style)
  ingress {
    description     = "Allow SSH from Web Server"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # Outbound All Traffic (required to download packages through NAT gateway)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-sg"
    Environment = var.environment
  }
}
