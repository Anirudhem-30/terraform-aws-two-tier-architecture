# Fetch data about AWS availability zones
data "aws_availability_zones" "available" {}

# Define local variables for reuse throughout the terraform configuration
locals {
  # Derive a name from the basename of the current working directory
  name   = "${basename(path.cwd)}"
  # Set the region where resources will be created
  region = "eu-west-1"

  # Define the CIDR block for the VPC
  vpc_cidr = "10.0.0.0/16"
  # Slice the available AZs data to use only the first two AZs
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  # Define common tags to apply to resources
  tags = {
    Example    = local.name
  }
}

# Create a VPC using the Terraform AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.0"

  # Set the name and CIDR block for the VPC
  name = local.name
  cidr = local.vpc_cidr

  # Assign availability zones, private, and public subnets
  azs                 = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets      = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  private_subnet_names = ["Private-${local.name}-${local.azs.0}", "Private-${local.azs.1}"]
}

# Define a security group for public-facing EC2 instances
resource "aws_security_group" "public_ec2" {
  name        = "web-sg"
  description = "sg for webserver ec2"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = local.name
  }
}

# Define ingress rules for the public EC2 security group
resource "aws_vpc_security_group_ingress_rule" "public_ec2_ingress" {
  security_group_id = aws_security_group.public_ec2.id
  for_each = var.web_sg_ingress
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_blocks
  from_port         = each.value.port
  ip_protocol       = each.value.protocol
  to_port           = each.value.port
}

# Define egress rules for the public EC2 security group
resource "aws_vpc_security_group_egress_rule" "public_ec2_egress" {
  security_group_id = aws_security_group.public_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Fetch the latest Amazon Linux AMI for 2023
data "aws_ami" "amz_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

# Create an EC2 instance for web service
resource "aws_instance" "web" {
  ami           = data.aws_ami.amz_2023.id
  instance_type = "t3.small"
  user_data = filebase64("${path.module}/user-data.sh")
  vpc_security_group_ids = [aws_security_group.public_ec2.id]
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  #key_name = 
  tags = {
    Name = local.name
  }
}
# Create an IAM role for the EC2 instance to interact with RDS
resource "aws_iam_role" "ec2_rds_role" {
  name = "ec2_rds_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Attach a policy to the IAM role to allow full RDS access
resource "aws_iam_role_policy" "rds_access" {
  name = "rds_access"
  role = aws_iam_role.ec2_rds_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds:*"
        ]
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}
# Create an instance profile and associate it with the role
resource "aws_iam_instance_profile" "ec2_rds_profile" {
  name = "ec2_rds_profile"
  role = aws_iam_role.ec2_rds_role.name
}

# Define a subnet group for the RDS instance
resource "aws_db_subnet_group" "db_backend" {
  name       = "db_backend"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "rds_backend"
  }
}

# Define a parameter group for the RDS instance
resource "aws_db_parameter_group" "db_backend" {
  name   = "db-backend"
  family = "MySQL8.0"
}

# Create an RDS instance for the database backend
resource "aws_db_instance" "db_backend" {
  identifier             = "db-backend"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "mysql"
  engine_version         = "8.0.35"
  username               = "db_user"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_backend.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.db_backend.name
  publicly accessible    = true
  skip_final_snapshot    = true
}

# Define a security group for the RDS instance
resource "aws_security_group" "rds" {
  name        = "rds_sg"
  description = "SG for RDS"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "rds_sg"
  }
}

# Define inbound rules for the RDS security group
resource "aws_vpc_security_group_ingress_rule" "db_inbound" {
  security_group_id = aws_security_group.rds.id
  for_each = var.db_sg
  description = each.value.description
  ip_protocol = each.value.protocol
  referenced_security_group_id = aws_security_group.public_ec2.id
  to_port = each.value.port
  from_port = each.value.port
}