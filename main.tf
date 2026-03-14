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

  tags = { Name = var.vpc_name }
}

# ----------------
# Subnets
# ----------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.public_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.public_available_zone
  tags = { Name = var.public_subnet_name }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = var.private_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.private_available_zone
  tags = { Name = var.private_subnet_name }
}

# ----------------
# Internet Gateway
# ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags   = { Name = var.igw_name }
}

# ----------------
# Default Route Table
# ----------------
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.my-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_default_route_table.default.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_default_route_table.default.id
}

# ----------------
# Security Group
# ----------------
resource "aws_security_group" "sg" {
  name        = var.security_group_name
  description = var.description_sg
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
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
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------
# RDS Subnet Group
# ----------------
resource "aws_db_subnet_group" "db_subnet" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
  tags       = { Name = "db-subnet-group" }
}

# ----------------
# RDS MariaDB
# ----------------
resource "aws_db_instance" "rds" {
  identifier             = "mariadb-instance"
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "mariadb"
  engine_version         = "10.6"
  instance_class         = "db.t4g.micro"
  db_name                = "studentapp"
  username               = "admin"
  password               = "prateek123"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.sg.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# ----------------
# EC2 Instance with Python + Tomcat + WAR
# ----------------
resource "aws_instance" "app_server" {
  ami                    = var.image_instance
  instance_type          = var.instance_type
  key_name               = var.instance_key
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install java -y
yum install python3 -y

curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
tar -xzvf apache-tomcat-9.0.115.tar.gz -C /opt

/opt/apache-tomcat-9.0.115/bin/catalina.sh start

cd /opt/apache-tomcat-9.0.115/webapps/
curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war

cd /opt/apache-tomcat-9.0.115/lib/
curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar

python3 - <<PY
f = open('/opt/apache-tomcat-9.0.115/conf/context.xml', 'r')
lines = f.readlines()
f.close()
resource = '    <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="500" maxIdle="30" maxWaitMillis="1000" username="admin" password="prateek123" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://${aws_db_instance.rds.address}:3306/studentapp?useUnicode=yes&amp;characterEncoding=utf8"/>\n'
lines.insert(-1, resource)
f = open('/opt/apache-tomcat-9.0.115/conf/context.xml', 'w')
f.writelines(lines)
f.close()
PY

/opt/apache-tomcat-9.0.115/bin/catalina.sh stop
/opt/apache-tomcat-9.0.115/bin/catalina.sh start
EOF

  tags = { Name = var.private_instance_name }
}
