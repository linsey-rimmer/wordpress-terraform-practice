resource "aws_vpc" "networking_lab_vpc" {
  cidr_block = "10.0.0.0/16" 
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"

  tags = {
    Name = "Networking-Lab-VPC-Linsey"
  }
}

resource "aws_subnet" "my_private_subnet" {
  vpc_id = aws_vpc.networking_lab_vpc.id 
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "my-private-subnet"
  }
}

resource "aws_subnet" "my_public_subnet" {
  vpc_id = aws_vpc.networking_lab_vpc.id 
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "my-public-subnet"
  }
}   

resource "aws_subnet" "my_second_public_subnet" {
  vpc_id = aws_vpc.networking_lab_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "my-second-public-subnet"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds_subnet_group"
  subnet_ids = [ aws_subnet.my_public_subnet.id, aws_subnet.my_second_public_subnet.id ]

  tags = {
    Name = "rds_subnet_group"
  }
}

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.networking_lab_vpc.id 

  tags = {
    Name = "networking-lab-internet-gateway"
  }
}

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
#
# Resources to connect first public subnet to the internet 
#
###########################

resource "aws_route_table_association" "public_subnet_to_route_table_association" {
  subnet_id = aws_subnet.my_public_subnet.id 
  route_table_id = aws_route_table.networking-lab-route-table.id 
}

###########################
#
# Resources to connect second public subnet to the internet 
#
###########################

resource "aws_route_table_association" "second_public_subnet_to_route_table_association" {
  subnet_id = aws_subnet.my_second_public_subnet.id 
  route_table_id = aws_route_table.networking-lab-route-table.id 
}

###########################
###########################


resource "aws_security_group" "rds_sc" {
  name = "rds_sc"
  description = "Security group to store RDS instance."
  vpc_id = aws_vpc.networking_lab_vpc.id 
}

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

resource "aws_security_group_rule" "inbound_sql_rule" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  source_security_group_id = aws_security_group.webserver_sc.id
  security_group_id = aws_security_group.rds_sc.id
}

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

resource "aws_instance" "my_public_instance" {
  ami = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.my_public_subnet.id 
  vpc_security_group_ids = [ aws_security_group.webserver_sc.id ]
  key_name = "vockey"

  tags = {
    Name = "my_public_instance"
  }
}

resource "aws_instance" "my_private_instance" {
  ami = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.my_private_subnet.id 
  vpc_security_group_ids = [ aws_security_group.webserver_sc.id ]
  key_name = "vockey"

  tags = {
    Name = "my_private_instance"
  }
}

## Need to create security group that allows for SSH access 