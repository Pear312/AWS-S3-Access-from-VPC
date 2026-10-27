provider "aws" {
	region = var.region
}

module "vpc_1" {
	source = "../../modules/vpc"

	cidr_block = "10.0.0.0/16"
	env = var.env
	instance_number = "1"
	igw_name = "IGW 1"
}

module "subnet_1" {
	source = "../../modules/subnet"

	vpc_id = module.vpc_1.vpc_id
	cidr_block = "10.0.0.0/24"
	availability_zone = "us-east-1a"
	instance_number = "1"
}

module "network_acl" {
	source = "../../modules/network_acl"

	vpc_id = module.vpc_1.vpc_id
  	subnet_ids = [module.subnet_1.subnet_id]

	ingress = [
		{
			protocol   = "-1"
			rule_no    = 100
			action     = "allow"
			cidr_block = "0.0.0.0/0"
			from_port  = 0
			to_port    = 0
		}
	]

	egress = [
		{
			protocol   = "-1"
			rule_no    = 100
			action     = "allow"
			cidr_block = "0.0.0.0/0"
			from_port  = 0
			to_port    = 0
		}
	]
}

module "route_table" {
	source = "../../modules/routes"

	vpc_id = module.vpc_1.vpc_id
	subnet_id = [module.subnet_1.subnet_id]

	routes = [
		{
			cidr_block = "10.0.0.0/16"
    		gateway_id = "local"
		},
		{
			cidr_block = "0.0.0.0/0"
      		gateway_id = module.vpc_1.internet_gateway_id
		}
	]

	routetable_name = "Route Table 1"
}

module "security_group" {
	source = "../../modules/security_group"

	name = "Security Group 1"
	description = "security group for ec2"
	vpc_id = module.vpc_1.vpc_id

	ingress = [
		{
			description = "Allow all inbound traffic"
			from_port   = 0
			to_port     = 0
			protocol    = "-1"
			cidr_blocks = ["0.0.0.0/0"]
		}
	]

	egress = [
		{
			description = "Allow all outbound traffic"
			from_port   = 0
			to_port     = 0
			protocol    = "-1"
			cidr_blocks = ["0.0.0.0/0"]
		}
	]
}

module "instance" {
	source = "../../modules/EC2"

	ami = "ami-0bdc7d025135d7b49"
	instance_type = "t2.micro"

	subnet_id = module.subnet_1.subnet_id
	security_group_ids = [module.security_group.security_group_id]

	name = "Instance - VPC 1"
}


resource "aws_s3_bucket" "this_bucket" {
  bucket = "emai-my-test-bucket"
  force_destroy = true

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_only_endpoint" {
  bucket = aws_s3_bucket.this_bucket.id
  policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyAccessUnlessFromVpcEndpoint",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "${aws_s3_bucket.this_bucket.arn}",
          "${aws_s3_bucket.this_bucket.arn}/*"
        ],
        "Condition": {
          "StringNotEquals": {
            "aws:sourceVpce": "${aws_vpc_endpoint.this_endpoint.id}",
            "aws:PrincipalArn": "arn:aws:iam::768898187522:user/ericmai"
          }
        }
      }
    ]
  }
  POLICY

}

resource "aws_vpc_endpoint" "this_endpoint" {
  vpc_id       = module.vpc_1.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"
}

