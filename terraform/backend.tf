terraform {
  backend "s3" {
    bucket       = "kritesh-dynamo-db-bucket"
    key          = "nest-crud/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
