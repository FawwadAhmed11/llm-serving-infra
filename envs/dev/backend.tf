terraform {
    backend "s3" {
        bucket          = "fawwad-tf-state"
        key             = "dev/terraform.tfstate"
        region          = "us-east-1"
        dynamodb_table  = "fawwad-tf-locks"
        encrypt         = true
    }
}