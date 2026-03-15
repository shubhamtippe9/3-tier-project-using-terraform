provider "aws" {
  region = var.region
}

# ----------------
# VPC
# ----------------
resource "aws_vpc" "my-vpc" {
  cidr_block           = var.mumbai_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# ----------------
# Subnets
# ----------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.public_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.public_available_zone

  tags = {
    Name = var.public_subnet_name
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.private_cidr_block
  map_public_ip_on_launch = false
  availability_zone       = var.private_available_zone

  tags = {
    Name = var.private_subnet_name
  }
}

# ----------------
# Internet Gateway
# ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = var.igw_name
  }
}


resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ----------------
# Route Tables
# ----------------
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

# ----------------
# Security Groups
# ----------------

resource "aws_security_group" "ec2_sg" {
  name        = var.security_group_name
  description = var.description_sg
  vpc_id      = aws_vpc.my-vpc.id

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

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-sg" }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL only from EC2 security group"
  vpc_id      = aws_vpc.my-vpc.id


  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# ----------------
# RDS Subnet Group
# ----------------
resource "aws_db_subnet_group" "my_db_subnet" {
  name       = "my-db-subnet-group"
  subnet_ids = [
    aws_subnet.public_subnet.id,
    aws_subnet.private_subnet.id
  ]

  tags = { Name = "db-subnet-group" }
}

# ----------------
# RDS Instance
# ----------------
resource "aws_db_instance" "my_db" {
  identifier             = "mariadb-instance"
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "mariadb"
  engine_version         = "10.6"
  instance_class         = "db.t4g.micro"
  db_name                = "studentapp"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# ----------------
# Public EC2 (Tomcat / app server)
# ----------------
resource "aws_instance" "ec2_public" {
  ami                    = var.image_instance
  instance_type          = var.instance_type
  key_name               = var.instance_key
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  user_data = <<-EOF
#!/bin/bash


yum install java-17-amazon-corretto python3 mariadb105 -y

cd /opt
curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
tar -xzf apache-tomcat-9.0.115.tar.gz

/opt/apache-tomcat-9.0.115/bin/catalina.sh start

cd /opt/apache-tomcat-9.0.115/webapps/
curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war

cd /opt/apache-tomcat-9.0.115/lib/
curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar

echo "Waiting for database to accept connections..."
until mysqladmin ping -h ${aws_db_instance.my_db.address} -u admin -p${var.db_password} --silent 2>/dev/null; do
  echo "DB not ready yet, retrying in 10s..."
  sleep 10
done
echo "Database is up."

python3 - <<PYTHON
f = open('/opt/apache-tomcat-9.0.115/conf/context.xml', 'r')
lines = f.readlines()
f.close()

resource = '    <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="500" maxIdle="30" maxWaitMillis="1000" username="admin" password="${var.db_password}" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://${aws_db_instance.my_db.address}:3306/studentapp?useUnicode=yes&amp;characterEncoding=utf8"/>\n'

for i, line in enumerate(lines):
    if '</Context>' in line:
        lines.insert(i, resource)
        break

f = open('/opt/apache-tomcat-9.0.115/conf/context.xml', 'w')
f.writelines(lines)
f.close()
PYTHON

/opt/apache-tomcat-9.0.115/bin/catalina.sh stop
/opt/apache-tomcat-9.0.115/bin/catalina.sh start

EOF

  tags = {

    Name = var.public_instance_name
  }
}

# ----------------
# Private EC2 (DB seed / init server)
# ----------------
resource "aws_instance" "ec2_private" {
  ami                    = var.image_instance
  instance_type          = var.instance_type
  key_name               = var.instance_key
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.private_subnet.id

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install mariadb105 -y
echo "Waiting for database to accept connections..."
until mysqladmin ping -h ${aws_db_instance.my_db.address} -u admin -p${var.db_password} --silent 2>/dev/null; do
  echo "DB not ready yet, retrying in 10s..."
  sleep 10
done
echo "Database is up."

mysql -h ${aws_db_instance.my_db.address} -u admin -p${var.db_password} <<MYSQL
CREATE DATABASE IF NOT EXISTS studentapp;
USE studentapp;
CREATE TABLE IF NOT EXISTS students(
student_id INT NOT NULL AUTO_INCREMENT,
student_name VARCHAR(100) NOT NULL,
student_addr VARCHAR(100) NOT NULL,
student_age VARCHAR(3) NOT NULL,
student_qual VARCHAR(20) NOT NULL,
student_percent VARCHAR(10) NOT NULL,
student_year_passed VARCHAR(10) NOT NULL,
PRIMARY KEY (student_id)
);
MYSQL

echo "Database and table created."

EOF

  tags = {

    Name = var.private_instance_name
  }
}


output "ec2_public_ip" {
  description = "Public IP of the Tomcat app server"
  value       = aws_instance.ec2_public.public_ip
}

output "rds_endpoint" {
  description = "RDS MariaDB endpoint"
  value       = aws_db_instance.my_db.address
}

output "app_url" {
  description = "Tomcat app URL"
  value       = "http://${aws_instance.ec2_public.public_ip}:8080/student"
}

