variable "region" {
  default = "ap-south-1"
}

variable "mumbai_vpc_cidr" {
  description = "CIDR of VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "My_VPC"
}

variable "public_cidr_block" {
  description = "Public Subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_available_zone" {
  description = "Public subnet availability zone"
  type        = string
  default     = "ap-south-1a"
}

variable "public_subnet_name" {
  description = "Public subnet name"
  type        = string
  default     = "public_subnet"
}

variable "private_cidr_block" {
  description = "Private Subnet CIDR Block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_available_zone" {
  description = "Private subnet availability zone"
  type        = string
  default     = "ap-south-1b"
}

variable "private_subnet_name" {
  description = "Private subnet name"
  type        = string
  default     = "private_subnet"
}

variable "igw_name" {
  description = "Internet Gateway Name"
  type        = string
  default     = "my_igw"
}

variable "nat_name" {
  description = "NAT Gateway name"
  type        = string
  default     = "my_nat"
}

variable "nat_route_table_name" {
  description = "NAT Gateway route table name"
  type        = string
  default     = "NAT_TB"
}

variable "security_group_name" {
  description = "Name of Security Group"
  type        = string
  default     = "My_SG"
}

variable "description_sg" {
  description = "Description of Security Group"
  type        = string
  default     = "Allow SSH, HTTP, and MySQL traffic"
}

variable "image_instance" {
  description = "AMI of EC2 instance"
  type        = string
  default     = "ami-051a31ab2f4d498f5"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.micro"
}

variable "instance_key" {
  description = "Key pair name for EC2 instance"
  type        = string
  default     = "Ryzen"
}

variable "public_instance_name" {
  description = "Public EC2 Instance name"
  type        = string
  default     = "Proxy_Server"
}

variable "private_instance_name" {
  description = "Private EC2 instance name (optional)"
  type        = string
  default     = "Application_Server"
}

