# Student Registration App — AWS Infrastructure (Terraform)

A fully automated AWS infrastructure for a Java/Tomcat based Student Registration web application, provisioned using Terraform.

---

## Architecture

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnet (ap-south-1a)
    ├── EC2 App Server (Tomcat 9 + Java 17)
    └── NAT Gateway
            │
            ▼
    Private Subnet (ap-south-1b)
            ├── EC2 DB Init Server
            └── RDS MariaDB (mariadb-instance)
```

### What gets created

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16` |
| Public Subnet | `10.0.0.0/20` — ap-south-1a |
| Private Subnet | `10.0.16.0/20` — ap-south-1b |
| Internet Gateway | Public internet access |
| NAT Gateway | Private subnet outbound access |
| EC2 App Server | Public subnet — Tomcat 9 + Java 17 |
| EC2 DB Init Server | Private subnet — creates DB schema |
| RDS MariaDB | `10.6` — `db.t4g.micro` — private |
| Security Group (EC2) | Ports 22, 80, 8080 open |
| Security Group (RDS) | Port 3306 — only from EC2 SG |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid credentials
- An existing EC2 Key Pair in `ap-south-1` region

---

## Project Structure

```
.
├── main.tf            # All AWS resources
├── variables.tf       # Variable declarations
├── terraform.tfvars   # Your actual values (do not commit!)
└── README.md
```

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
```

### 2. Create terraform.tfvars

```hcl
db_password = "your-strong-password"
```

>  Never commit `terraform.tfvars` to GitHub — add it to `.gitignore`

### 3. Configure AWS credentials

```bash
aws configure
```

### 4. Deploy

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted.

### 5. Access the app

After apply completes, you will see:

```
app_url       = "http://<public-ip>:8080/student"
ec2_public_ip = "<public-ip>"
rds_endpoint  = "<rds-endpoint>"
```

Open `app_url` in your browser — the Student Registration form will be live.

---

## What user_data does automatically

### Public EC2 (App Server)
1. Installs Java 17, Python3, MariaDB client
2. Downloads and starts Apache Tomcat 9
3. Downloads `student.war` and `mysql-connector.jar` from S3
4. Waits for RDS to be ready (retry loop — no hardcoded sleep)
5. Creates `studentapp` database and `students` table
6. Injects RDS endpoint into Tomcat `context.xml`
7. Restarts Tomcat with the new config

### Private EC2 (DB Init Server)
1. Installs MariaDB client
2. Waits for RDS to be ready (retry loop)
3. Creates `studentapp` database and `students` table (idempotent)

---

## Database Schema

```sql
CREATE TABLE students (
  student_id          INT NOT NULL AUTO_INCREMENT,
  student_name        VARCHAR(100) NOT NULL,
  student_addr        VARCHAR(100) NOT NULL,
  student_age         VARCHAR(3)   NOT NULL,
  student_qual        VARCHAR(20)  NOT NULL,
  student_percent     VARCHAR(10)  NOT NULL,
  student_year_passed VARCHAR(10)  NOT NULL,
  PRIMARY KEY (student_id)
);
```

---

## Security

| What | How |
|---|---|
| DB password | `sensitive` variable — never hardcoded |
| RDS access | Port 3306 scoped to EC2 security group only |
| RDS visibility | `publicly_accessible = false` |
| DB network | Reachable only from within the VPC |

---

## Debugging

SSH into the app server:
```bash
ssh -i your-key.pem ec2-user@<public-ip>
```

Check user_data logs:
```bash
sudo tail -100 /var/log/cloud-init-output.log
```

Check Tomcat logs:
```bash
sudo tail -100 /opt/apache-tomcat-9.0.115/logs/catalina.out
```

Verify DB connection:
```bash
mysql -h <rds-endpoint> -u admin -pYourPassword -e "SHOW TABLES;" studentapp
```

---

## Teardown

```bash
terraform destroy
```

>  `skip_final_snapshot = true` is set — all RDS data will be permanently deleted on destroy.

---

## .gitignore (recommended)

```
terraform.tfvars
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform |
| Cloud | AWS (ap-south-1 Mumbai) |
| App Server | Apache Tomcat 9 |
| Runtime | Java 17 (Amazon Corretto) |
| Database | MariaDB 10.6 on RDS |
| OS | Amazon Linux 2023 |
