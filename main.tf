# ===========================
# PROVIDER
# ===========================
provider "aws" {
  region = var.region
}

# ===========================
# VPC
# ===========================
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.mumbai_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# ===========================
# PUBLIC SUBNET
# ===========================
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.public_available_zone

  tags = {
    Name = var.public_subnet_name
  }
}

# ===========================
# PRIVATE SUBNET
# ===========================
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_cidr_block
  availability_zone = var.private_available_zone

  tags = {
    Name = var.private_subnet_name
  }
}

# ===========================
# INTERNET GATEWAY
# ===========================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = var.igw_name
  }
}

# ===========================
# PUBLIC ROUTE TABLE
# ===========================
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ===========================
# NAT GATEWAY
# ===========================
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = var.nat_name
  }
}

# ===========================
# PRIVATE ROUTE TABLE
# ===========================
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = var.nat_route_table_name
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ===========================
# SECURITY GROUP
# ===========================
resource "aws_security_group" "my_sg" {
  name        = var.security_group_name
  description = var.description_sg
  vpc_id      = aws_vpc.my_vpc.id

  # Allow SSH, HTTP, Tomcat, MySQL
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

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # Allow EC2 instances in VPC private subnet to RDS
    cidr_blocks = [var.private_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ===========================
# RDS SUBNET GROUP
# ===========================
resource "aws_db_subnet_group" "db_subnet" {
  name       = "my-db-subnet-group"
  subnet_ids = [
    aws_subnet.public_subnet.id,
    aws_subnet.private_subnet.id
  ]

  tags = {
    Name = "db-subnet-group"
  }
}

# ===========================
# RDS INSTANCE (MariaDB)
# ===========================
resource "aws_db_instance" "my_db" {
  identifier              = "mariadb-instance"
  allocated_storage       = 10
  storage_type            = "gp2"
  engine                  = "mariadb"
  engine_version          = "10.6"
  instance_class          = "db.t4g.micro"
  db_name                 = "studentapp"
  username                = "admin"
  password                = "Prateek12345"
  db_subnet_group_name    = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids  = [aws_security_group.my_sg.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
}

# ===========================
# EC2 INSTANCE (Tomcat App)
# ===========================
resource "aws_instance" "ec2_app" {
  ami                    = var.image_instance
  instance_type          = var.instance_type
  key_name               = var.instance_key
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]

  user_data = <<-EOF
    #!/bin/bashgi
    yum install java -y
    curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
    tar -xzvf apache-tomcat-9.0.115.tar.gz -C /opt
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh start
    cd /opt/apache-tomcat-9.0.115/webapps/
    curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
    cd /opt/apache-tomcat-9.0.115/lib/
    curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar
    FILE="/opt/apache-tomcat-9.0.115/conf/context.xml"
    sed -i '$i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="500" maxIdle="30" maxWaitMillis="1000" username="admin" password="Prateek12345" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://${aws_db_instance.my_db.endpoint}:3306/studentapp?useUnicode=yes&characterEncoding=utf8"/>' $FILE
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh stop
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh start
  EOF

  tags = {
    Name = var.public_instance_name
  }
}

# ===========================
# OUTPUT PUBLIC IP
# ===========================
output "ec2_public_ip" {
  value = aws_instance.ec2_app.public_ip
}