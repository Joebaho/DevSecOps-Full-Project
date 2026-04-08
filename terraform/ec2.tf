data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_default_vpc" "default" {

}

resource "aws_security_group" "allow_user_to_connect" {
  name        = "devsecops-full-project-sg"
  description = "Allow access to project services"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SMTP"
    from_port   = 25
    to_port     = 25
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SMTPS"
    from_port   = 465
    to_port     = 465
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom application ports"
    from_port   = 3000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-full-project-sg"
  }
}

data "aws_iam_policy_document" "jenkins_worker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_worker_role" {
  name               = "jenkins-worker-node-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_worker_assume_role.json

  tags = {
    Name = "jenkins-worker-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_worker_admin_access" {
  role       = aws_iam_role.jenkins_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "jenkins_worker_profile" {
  name = "jenkins-worker-node-profile"
  role = aws_iam_role.jenkins_worker_role.name
}

resource "aws_instance" "master_machine" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.allow_user_to_connect.id]
  user_data              = file("${path.module}/scripts/master-bootstrap.sh")

  tags = {
    Name = "Master Machine"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }
}

resource "aws_instance" "jenkins_worker_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.allow_user_to_connect.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_worker_profile.name
  user_data              = file("${path.module}/scripts/worker-bootstrap.sh")

  tags = {
    Name = "Jenkins worker node"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }
}
