terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "epsi-skhedim"

    workspaces {
      name = "aws-epsi-tf"
    }
  }
}