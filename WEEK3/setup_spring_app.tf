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

resource "aws_eip" "nat_eip" {
  vpc              = true
  public_ipv4_pool = "amazon"

  tags = {
    Name = "NAT GW Elastic IP"
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


# Private Subnet
resource "aws_subnet" "spring_priv_subnet_AZ1" {
  vpc_id            = aws_vpc.spring_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.AZ1

  tags = {
    Name = "Spring Subnet AZ1"
  }
}
resource "aws_subnet" "spring_priv_subnet_AZ2" {
  vpc_id            = aws_vpc.spring_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = var.AZ2

  tags = {
    Name = "Spring Subnet AZ2"
  }
}
resource "aws_subnet" "spring_priv_subnet_AZ3" {
  vpc_id            = aws_vpc.spring_vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = var.AZ3

  tags = {
    Name = "Spring Subnet AZ3"
  }
}

# Private Route Table & NAT Gateway
resource "aws_nat_gateway" "spring_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.spring_public_subnet_AZ1.id
}

resource "aws_default_route_table" "spring_default_rt" {
  default_route_table_id = aws_vpc.spring_vpc.default_route_table_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.spring_nat_gw.id
  }

  tags = {
    Name = "Spring Main RT"
  }
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

# Private Security Group
resource "aws_security_group" "spring_priv_sg" {
  vpc_id      = aws_vpc.spring_vpc.id
  name        = "spring_priv_sg"
  description = "Spring DB Security Group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = " Spring Private Security Group"
  }
}

# Key Pair
resource "aws_key_pair" "spring_app_key" {
  key_name   = "spring_app_key"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "public_instance1" {
  ami             = "ami-02b658ac34935766f"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.spring_app_key.key_name
  subnet_id       = aws_subnet.spring_public_subnet_AZ1.id
  security_groups = [aws_security_group.spring_public_sg.id]

  tags = {
    Name = "Public Instance"
  }
}
resource "aws_instance" "public_instance2" {
  ami             = "ami-02b658ac34935766f"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.spring_app_key.key_name
  subnet_id       = aws_subnet.spring_public_subnet_AZ2.id
  security_groups = [aws_security_group.spring_public_sg.id]

  tags = {
    Name = "Public Instance"
  }
}
resource "aws_instance" "public_instance3" {
  ami             = "ami-02b658ac34935766f"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.spring_app_key.key_name
  subnet_id       = aws_subnet.spring_public_subnet_AZ3.id
  security_groups = [aws_security_group.spring_public_sg.id]

  tags = {
    Name = "Public Instance"
  }
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

resource "aws_autoscaling_attachment" "spring_asg" {
  autoscaling_group_name = aws_autoscaling_group.spring_auto_scale_group.id
  elb                    = aws_elb.spring_elb.id
}

resource "aws_launch_template" "spring_launch_template" {
  name_prefix            = "spring"
  image_id               = "ami-02b658ac34935766f"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.spring_app_key.key_name
  vpc_security_group_ids = [aws_security_group.spring_priv_sg.id]

  user_data = filebase64("install_nginx.sh")

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Private Instance"
    }
  }
}

resource "aws_autoscaling_group" "spring_auto_scale_group" {
  desired_capacity    = 3
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.spring_priv_subnet_AZ1.id, aws_subnet.spring_priv_subnet_AZ2.id, aws_subnet.spring_priv_subnet_AZ3.id]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.spring_launch_template.id
    version = "$Latest"
  }
}


output "dns_name" {
  value = aws_elb.spring_elb.dns_name
}

