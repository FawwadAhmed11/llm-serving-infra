variable "vpc_name" {
    type    = string
    description = "VPC name"
    default = "Fawwad-test-VPC"
}

variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
}


variable "vpc_cidr_block" {
    description = "cidr block"
    type        = string
    default     = "10.0.0.0/16"
}

variable "list_public_subnet_cidrs" {
    description = "list of cidrs for public subnet"
    type        = list(string)

}

variable "list_private_subnet_cidrs" {
    description = "list of cidrs for private subnet"
    type        = list(string)

}

variable "list_availability_zones" {
    description = "list of availability zones"
    type        = list(string)
}