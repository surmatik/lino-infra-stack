terraform {
  backend "s3" {
    bucket         = "lino-cloud-prod-fra-tfstate-730335398363"
    key            = "strapi/main.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "lino-cloud-prod-fra-tfstate-lock" 
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# --- NETWORK ---

resource "aws_vpc" "main" {
  cidr_block                       = "172.31.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name    = "main-vpc"
    Project = "Lino-Cloud"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.31.32.0/20"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  ipv6_cidr_block         = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)

  tags = {
    Name    = "public-subnet-strapi"
    Project = "Lino-Cloud"
  }
}

resource "aws_egress_only_internet_gateway" "ipv6_outbound" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "ipv6_egress" {
  route_table_id              = aws_vpc.main.main_route_table_id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.ipv6_outbound.id
}

# --- COMPUTE ---

resource "aws_instance" "strapi" {
  ami           = "ami-076c75ba3c4c80556"
  instance_type = "t3.micro"
  key_name      = "prod-strapi-fra-01"
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [
    "sg-01e238d749941ff03",
    "sg-0b32e87444fd5c2d3",
  ]

  associate_public_ip_address = false
  ipv6_address_count          = 1

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name      = "lino-aws-fra-strapi-01-strapi"
    Project   = "Lino-Cloud"
    ManagedBy = "Terraform"
  }
}