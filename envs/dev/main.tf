provider "aws" {
    region  = "us-east-1"
}

module "vpc_dev" {
    source = "../../modules/vpc"

    vpc_name                    = "fawwad-dev-vpc"
    cluster_name                = "fawwad-cluster"
    vpc_cidr_block              = "10.0.0.0/16"
    list_public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
    list_private_subnet_cidrs   = ["10.0.3.0/24", "10.0.4.0/24"]
    list_availability_zones     = ["us-east-1a", "us-east-1b"]

}

module "eks" {
    source                  = "../../modules/eks" 

    cluster_name            = "fawwad-cluster"
    cluster_version         = "1.32"
    vpc_id                  = module.vpc_dev.vpc_id
    private_subnet_ids      = module.vpc_dev.private_subnet_ids
    node_instance_type      = "t3.small"
    node_desired_size       = 2
  node_min_size             = 1
  node_max_size             = 3

}