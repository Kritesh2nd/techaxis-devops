terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    tls = {
      source = "hashicorp/tls"
    }

    local = {
      source = "hashicorp/local"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "nest-crud-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  filename        = "${path.module}/my-ec2-key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

resource "aws_vpc" "kritesh_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-aws-study-vpc"
  }
}

resource "aws_internet_gateway" "kritesh_igw" {
  vpc_id = aws_vpc.kritesh_vpc.id

  tags = {
    Name = "main-aws-study-igw"
  }
}

resource "aws_subnet" "kritesh_subnet" {
  vpc_id                  = aws_vpc.kritesh_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "main-public-subnet"
  }
}

resource "aws_route_table" "kritesh_route_table" {
  vpc_id = aws_vpc.kritesh_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kritesh_igw.id
  }

  tags = {
    Name = "main-public-route-table"
  }
}

resource "aws_route_table_association" "kritesh_rta" {
  subnet_id      = aws_subnet.kritesh_subnet.id
  route_table_id = aws_route_table.kritesh_route_table.id
}

resource "aws_security_group" "pipeline_sg" {
  name        = "jenkins-servers-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.kritesh_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-servers-sg"
  }
}

resource "aws_security_group" "deployment_sg" {
  name        = "deployment-sg"
  description = "Security group for deployment server"
  vpc_id      = aws_vpc.kritesh_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "deployment-sg"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Security group for Grafana and Loki"
  vpc_id      = aws_vpc.kritesh_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 3100
    to_port   = 3100
    protocol  = "tcp"

    security_groups = [
      aws_security_group.pipeline_sg.id,
      aws_security_group.deployment_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "kritesh_monitoring_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.ssh_key.key_name
  subnet_id     = aws_subnet.kritesh_subnet.id

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.monitoring_sg.id
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user-data/monitoring_userdata.sh")

  tags = {
    Name = "kritesh-monitoring-server"
  }
}

resource "aws_instance" "kritesh_jenkins_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.ssh_key.key_name
  subnet_id     = aws_subnet.kritesh_subnet.id

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.pipeline_sg.id
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }


  user_data = templatefile("${path.module}/user-data/jenkins_userdata.sh", {
    loki_url = "http://${aws_instance.kritesh_monitoring_server.private_ip}:3100"
  })

  tags = {
    Name = "kritesh-jenkins-server"
  }
}

resource "aws_instance" "kritesh_deployment_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.ssh_key.key_name
  subnet_id     = aws_subnet.kritesh_subnet.id

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.deployment_sg.id
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/deployment_userdata.sh", {
    loki_url = "http://${aws_instance.kritesh_monitoring_server.private_ip}:3100"
  })
  tags = {
    Name = "kritesh-deployment-server"
  }
}
