terraform {
  backend "s3" {
    bucket = "epsi-skhedim"
    key    = "epsi/terraform.tfstate"
    region = "us-east-1"
  }
}