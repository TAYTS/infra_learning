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

resource "aws_route_table" "spring_public_rt" {
  vpc_id = aws_vpc.spring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spring_gw.id
  }

  tags = {
    Name = "Spring Public RT"
  }
}

# Public Subnet
resource "aws_subnet" "spring_public_subnet_AZ1" {
  vpc_id                  = aws_vpc.spring_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.AZ1
  map_public_ip_on_launch = true

  tags = {
    Name = "Spring Public Subnet AZ1"
  }
}
resource "aws_subnet" "spring_public_subnet_AZ2" {
  vpc_id                  = aws_vpc.spring_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.AZ2
  map_public_ip_on_launch = true

  tags = {
    Name = "Spring Public Subnet AZ2"
  }
}
resource "aws_subnet" "spring_public_subnet_AZ3" {
  vpc_id                  = aws_vpc.spring_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = var.AZ3
  map_public_ip_on_launch = true

  tags = {
    Name = "Spring Public Subnet AZ3"
  }
}

# Public Route Table
resource "aws_route_table_association" "spring_public_rt_subnet_ass1" {
  subnet_id      = aws_subnet.spring_public_subnet_AZ1.id
  route_table_id = aws_route_table.spring_public_rt.id
}
resource "aws_route_table_association" "spring_public_rt_subnet_ass2" {
  subnet_id      = aws_subnet.spring_public_subnet_AZ2.id
  route_table_id = aws_route_table.spring_public_rt.id
}
resource "aws_route_table_association" "spring_public_rt_subnet_ass3" {
  subnet_id      = aws_subnet.spring_public_subnet_AZ3.id
  route_table_id = aws_route_table.spring_public_rt.id
}


# Public Security Group
resource "aws_security_group" "spring_public_sg" {
  vpc_id      = aws_vpc.spring_vpc.id
  name        = "spring_public_sg"
  description = "Spring App Security Group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = " Spring Public Security Group"
  }
}

# Key Pair
resource "aws_key_pair" "spring_app_key" {
  key_name   = "spring_app_key"
  public_key = file(var.public_key_path)
}

# HA Setup
resource "aws_elb" "spring_elb" {
  name            = "spring-elb"
  subnets         = [aws_subnet.spring_public_subnet_AZ1.id, aws_subnet.spring_public_subnet_AZ2.id, aws_subnet.spring_public_subnet_AZ3.id]
  security_groups = [aws_security_group.spring_public_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 2
    target              = "HTTP:80/"
    interval            = 5
  }

  tags = {
    Name = "Spring ELB"
  }
}

# IAM Role for ECS
resource "aws_iam_role" "spring-app-ecs-role" {
  name = "spring-app-ecs-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name = "Spring ECS Role"
  }
}

# Use AWS Managed Policy
data "aws_iam_policy" "ECSPolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach ECS policy to the new role
resource "aws_iam_role_policy_attachment" "ecs-role-policy-attach" {
  role       = aws_iam_role.spring-app-ecs-role.name
  policy_arn = data.aws_iam_policy.ECSPolicy.arn
}

# ECS Task
resource "aws_ecs_task_definition" "spring-app-task" {
  family                = "spring-app-task"
  container_definitions = file("task-definitions/service.json")
  task_role_arn         = aws_iam_role.spring-app-ecs-role.arn

  tags = {
    Name = "Spring ECS Task"
  }
}

# ECS Service
resource "aws_ecs_service" "spring-app-service" {
  name            = "spring-app-service"
  cluster         = aws_ecs_cluster.spring-app-cluster.id
  task_definition = aws_ecs_task_definition.spring-app-task.arn
  desired_count   = 3
  launch_type     = "EC2"

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    elb_name       = aws_elb.spring_elb.name
    container_name = "spring-app"
    container_port = 8081
  }

  tags = {
    Name = "Spring ECS Service"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "spring-app-cluster" {
  name = "spring-app-cluster"

  tags = {
    Name = "Spring ECS Cluster"
  }
}

# Auto-scaling Group for ECS cluster
resource "aws_autoscaling_group" "spring_auto_scale_group" {
  desired_capacity     = 3
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.spring_public_subnet_AZ1.id, aws_subnet.spring_public_subnet_AZ2.id, aws_subnet.spring_public_subnet_AZ3.id]
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.spring-ecs-lc.name
  termination_policies = ["OldestInstance"]
}

# Attach Auto-scaling Group to ECS cluster
resource "aws_ecs_capacity_provider" "spring-ecs-capcity-provider" {
  name = "spring-ecs-capcity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.spring_auto_scale_group.arn
  }
}

# Auto-scaling Instance Launch Configuration
resource "aws_launch_configuration" "spring-ecs-lc" {
  security_groups             = [aws_security_group.spring_public_sg.id]
  key_name                    = aws_key_pair.spring_app_key.key_name
  image_id                    = "ami-02cb4c2d39ad51e5a"
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.spring-ecs-instance-profile.name
  associate_public_ip_address = true
  user_data                   = data.template_file.user_data.rendered
}

# Instance profile for linking the IAM with EC2 instance
resource "aws_iam_instance_profile" "spring-ecs-instance-profile" {
  name = "spring-ecs-instance-profile"
  role = aws_iam_role.spring-app-ecs-role.name
}


# User-data required for the instances launched with Auto-scaling Group to be registered with
# ECS cluster
data "template_file" "user_data" {
  template = file("templates/user-data.sh")

  vars = {
    cluster_name = aws_ecs_cluster.spring-app-cluster.name
  }
}

output "dns_name" {
  value = aws_elb.spring_elb.dns_name
}

