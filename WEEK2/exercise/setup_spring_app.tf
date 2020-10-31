terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_vpc" "spring_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Spring VPC"
  }
}

resource "aws_internet_gateway" "spring_gw" {
  vpc_id = aws_vpc.spring_vpc.id

  tags = {
    Name = "Spring GW"
  }
}

resource "aws_route_table" "spring_rt" {
  vpc_id = aws_vpc.spring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spring_gw.id
  }

  tags = {
    Name = "Spring RT"
  }
}

resource "aws_subnet" "spring_subnet" {
  vpc_id                  = aws_vpc.spring_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "Spring Subnet"
  }
}

resource "aws_route_table_association" "spring_rt_subnet_ass" {
  subnet_id      = aws_subnet.spring_subnet.id
  route_table_id = aws_route_table.spring_rt.id
}

resource "aws_security_group" "spring_app_sg" {
  vpc_id      = aws_vpc.spring_vpc.id
  name        = "spring_app_sg"
  description = "Spring App Security Group"
}

resource "aws_security_group_rule" "allow_ssh" {
  security_group_id = aws_security_group.spring_app_sg.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_http" {
  security_group_id = aws_security_group.spring_app_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_app_access" {
  security_group_id = aws_security_group.spring_app_sg.id
  type              = "ingress"
  from_port         = 8081
  to_port           = 8081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.spring_app_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_key_pair" "spring_app_key" {
  key_name   = "spring_app_key"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "spring_instance" {
  ami               = "ami-0c8e97a27be37adfd"
  instance_type     = "t2.micro"
  key_name          = aws_key_pair.spring_app_key.key_name
  availability_zone = var.AZ
  subnet_id         = aws_subnet.spring_subnet.id
  security_groups   = [aws_security_group.spring_app_sg.id]

  provisioner "file" {
    source      = "/Users/taytzushieh/Courses/thoughtworks_learning/WEEK1/gs-spring-boot/initial/target/spring-boot-0.0.1-SNAPSHOT.jar"
    destination = "/home/ubuntu/app.jar"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file(var.private_key_path)
    }
  }

  provisioner "file" {
    source      = "/Users/taytzushieh/Courses/thoughtworks_learning/WEEK2/exercise/helloapp.service"
    destination = "/home/ubuntu/helloapp.service"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file(var.private_key_path)
    }
  }

  user_data = file("setup_app.sh")

  tags = {
    Name = "Spring App"
  }
}

resource "aws_eip" "ip" {
  vpc      = true
  instance = aws_instance.spring_instance.id

  tags = {
    Name = "Spring Subnet"
  }
}

output "ip" {
  value = aws_eip.ip.public_ip
}

