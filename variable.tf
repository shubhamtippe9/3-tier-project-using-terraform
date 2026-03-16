variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

# ---------------- VPC ----------------

variable "my_vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "my-vpc"
}

# ---------------- Public Subnet ----------------

variable "public_cidr_block" {
  description = "Public Subnet CIDR block"
  type        = string
  default     = "10.0.0.0/20"
}

variable "public_available_zone" {
  description = "Public subnet availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "public_subnet_name" {
  description = "Public subnet name"
  type        = string
  default     = "public-subnet"
}

# ---------------- Private Subnet ----------------

variable "private_cidr_block" {
  description = "Private Subnet CIDR block"
  type        = string
  default     = "10.0.16.0/20"
}

variable "private_available_zone" {
  description = "Private subnet availability zone"
  type        = string
  default     = "us-east-1b"
}

variable "private_subnet_name" {
  description = "Private subnet name"
  type        = string
  default     = "private-subnet"
}

# ---------------- Internet Gateway ----------------

variable "igw_name" {
  description = "Internet Gateway Name"
  type        = string
  default     = "my-igw"
}

# ---------------- Security Group ----------------

variable "security_group_name" {
  description = "Security Group Name"
  type        = string
  default     = "ec2-sg"
}

variable "description_sg" {
  description = "Security Group Description"
  type        = string
  default     = "Allow SSH, HTTP, and Tomcat access for EC2"
}

# ---------------- Database ----------------


variable "db_password" {
  description = "Password for the RDS MariaDB instance"
  type        = string
  sensitive   = true
}

# ---------------- EC2 Instance ----------------

variable "image_instance" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-02dfbd4ff395f2a1b"
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_key" {
  description = "EC2 Key Pair Name"
  type        = string
  default     = "north"
}

# ---------------- Instance Names ----------------


variable "public_instance_name" {
  description = "Public EC2 instance name (runs Tomcat)"
  type        = string
  default     = "app-server"
}

variable "private_instance_name" {
  description = "Private EC2 instance name (runs DB seed scripts)"
  type        = string
  default     = "db-init-server"
}
