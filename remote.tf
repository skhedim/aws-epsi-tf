terraform {
  backend "remote" {
    organization = "epsi-skhedim"

    workspaces {
      name = "aws-epsi-tf"
    }
  }
}