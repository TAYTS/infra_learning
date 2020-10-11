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
  region  = "ap-southeast-1"
}

resource "aws_instance" "example" {
  ami           = "ami-0c8e97a27be37adfd"
  instance_type = "t2.micro"
}

