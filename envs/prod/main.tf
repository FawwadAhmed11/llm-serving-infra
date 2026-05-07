provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name                  = "fawwad-prod-vpc"
  vpc_cidr_block            = "10.0.0.0/16"
  list_public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  list_private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  list_availability_zones   = ["us-east-1a", "us-east-1b"]
}