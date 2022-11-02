##########################
#
# NETWORKING
#
##########################

##############################
# Create a VPC 
##############################

resource "aws_vpc" "networking_lab_vpc" {
  cidr_block = "10.0.0.0/16" 
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"

  tags = {
    Name = "Networking-Lab-VPC-Linsey"
  }
}

##############################
# Create a public subnet for the webservers  
##############################

resource "aws_subnet" "my_public_subnet" {
  vpc_id = aws_vpc.networking_lab_vpc.id 
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "my-public-subnet"
  }
}   

##############################
# Create two private subnets
#
# note - two private subnets are required in order to provide the RDS with a subnet group later. 
# Multi AZ / subnets support high availability, so this is built in as a requirement to ensure the option is there later.
##############################

resource "aws_subnet" "private_subnet_1" {
  vpc_id = aws_vpc.networking_lab_vpc.id 
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id = aws_vpc.networking_lab_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet_2"
  }
}

##############################
# Create a subnet group 
# Use: to link private subnets to RDS later 
##############################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds_subnet_group"
  subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]

  tags = {
    Name = "rds_subnet_group"
  }
}

##############################
# Create an internet gateway
# Use: connect VPC to the internet  
##############################

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.networking_lab_vpc.id 

  tags = {
    Name = "networking-lab-internet-gateway"
  }
}

##############################
# Create a route table 
##############################

resource "aws_route_table" "networking-lab-route-table" {
  vpc_id = aws_vpc.networking_lab_vpc.id 

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id 
  }

  tags = {
    Name = "my_public_route_table"
  }
}

###########################
# Associate route table with public subnet
# Use: allows traffic to and from the internet into subnet  
###########################

resource "aws_route_table_association" "public_subnet_to_route_table_association" {
  subnet_id = aws_subnet.my_public_subnet.id 
  route_table_id = aws_route_table.networking-lab-route-table.id 
}

##########################
#
# SECURITY GROUPS 
#
##########################

##########################
# Create security group for backend database
# Note - no ingress or egress rules are given because these a cycle referential to the webserver security group that hasn't been created yet. 
# Rules will be implemented later via aws_security_group_rule resource
##########################

resource "aws_security_group" "rds_sc" {
  name = "rds_sc"
  description = "Security group to store RDS instance."
  vpc_id = aws_vpc.networking_lab_vpc.id 
}

##############################
# Create webserver security group with inbound and outbound rules 
##############################

resource "aws_security_group" "webserver_sc" {
  name = "webserver_sc"
  description = "Security group for wordpress web servers."
  vpc_id = aws_vpc.networking_lab_vpc.id 

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
  egress {
    description = "MYSQL/Aurora"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [ aws_security_group.rds_sc.id ]
  }

  #####
  # Terraform removes default all traffic outbound connection. This block replaces it. 
  # egress {
  #   from_port = 0
  #   to_port = 0 
  #   protocol = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  # }
  ######
}

##############################
# Implement inbound rule onto database security group to allow SQL requests 
##############################

resource "aws_security_group_rule" "inbound_sql_rule" {
  type = "ingress"
  from_port = 3306 # port number for MySQL 
  to_port = 3306
  protocol = "tcp"
  source_security_group_id = aws_security_group.webserver_sc.id
  security_group_id = aws_security_group.rds_sc.id
}

##############################
# Create an RDS instance 
##############################

resource "aws_db_instance" "my_wordpress_db" {
  allocated_storage = 10
  db_name = "mywordpressdb"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t3.micro"
  username = "admin"
  password = "password"
  multi_az = "false" 
  availability_zone = "us-east-1a"
  vpc_security_group_ids = [ aws_security_group.rds_sc.id ]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.id

  tags = {
    Name = "mywordpressdb"
  }
}

##############################
# Bring in user data
##############################

data "template_file" "wordpress_install_user_data" {
  template = file("wordpress_user_data.txt")
}

data "template_cloudinit_config" "config" {
  gzip = "false"
  base64_encode = "false"

  part {
    content_type = "text/x-shellscript"
    content = <<-EOF
      #!/bin/bash
      yum -y install httpd php php-mysql
      wget https://wordpress.org/wordpress-5.1.1.tar.gz
      tar -xzf wordpress-5.1.1.tar.gz
      cp -r wordpress/* /var/www/html
      rm -rf wordpress*
      cd /var/www/html
      chmod -R 755 wp-content
      chown -R apache:apache wp-content
      systemctl enable httpd && systemctl start httpd 
    EOF
  }
}

##############################
# Create x2 EC2 instances 
# note - two instances have been created to allow for load balancing later 
##############################

resource "aws_instance" "wordpress_instance_1" {
  ami = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.my_public_subnet.id 
  vpc_security_group_ids = [ aws_security_group.webserver_sc.id ]
  key_name = "vockey"
  # user_data = "${file("wordpress_user_data.txt")}" - execution doesn't work because we need to be able to reference attributes generated from preceding script 
  user_data = data.template_cloudinit_config.config.rendered 

  tags = {
    Name = "wordpress_instance_1"
  }

  depends_on = [
    aws_db_instance.my_wordpress_db
  ]
}

resource "aws_instance" "wordpress_instance_2" {
  ami = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.my_public_subnet.id 
  vpc_security_group_ids = [ aws_security_group.webserver_sc.id ]
  key_name = "vockey"
  user_data = data.template_cloudinit_config.config.rendered 

  tags = {
    Name = "wordpress_instance_2"
  }

  depends_on = [
    aws_db_instance.my_wordpress_db
  ]
}
