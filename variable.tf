# Define a map variable for web security group ingress rules
variable "web_sg_ingress" {
  # Specify the type as a map of objects to hold the rule details
  type = map(object(
    {
      description = string               # Description of the ingress rule
      port        = number               # The port number to which this rule applies
      protocol    = string               # The protocol used (e.g., TCP, UDP)
      cidr_blocks = string               # CIDR block to specify the IP address range
      referenced_security_group_id = string  # Referenced security group ID, if any
    }
  ))
  # Provide default rules for common web ports 80 (HTTP), 443 (HTTPS), and 22 (SSH)
  default = {
    "80" = {
      description = "Port 80"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"                # Allow all IP addresses
      referenced_security_group_id = null     # No specific referenced SG ID
    }
    "443" = {
      description = "Port 443"
      port        = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"                # Allow all IP addresses
      referenced_security_group_id = null     # No specific referenced SG ID
    }
    "22" = {
      description = "Port 22"
      port        = 22      
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"                # Allow all IP addresses
      referenced_security_group_id = null     # No specific referenced SG ID
    }
  }
}

# Define a map variable for database security group settings
variable "db_sg" {
  # Specify the type as a map of objects for database security group rules
  type = map(object(
    {
      description = string               # Description of the DB security rule
      port        = number               # The port number for the rule, typically 3306 for MySQL
      protocol    = string               # The protocol, usually TCP for databases
      cidr_blocks = string               # CIDR block to specify the IP address range
      #referenced_security_group_id = string  # Referenced security group ID, if applicable
    }
  ))
  # Provide a default rule for MySQL's default port 3306
  default = {
    "3306" = {
      description = "Port 3306"
      port        = 3306
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"                # Allow all IP addresses
      #referenced_security_group_id = aws_vpc_security_group_ingress_rule.public_ec2.id
    }
  }
}

# Define a variable to store the database password, marked as sensitive
variable "db_password" {
  description = "RDS root user password"  # Description of the variable
  type        = string                    # Type is string
  sensitive   = true                      # Marked as sensitive to prevent it from being logged or outputted in plain text
}