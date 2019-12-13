/*
  https://www.terraform.io/docs/configuration/terraform.html
*/
terraform {
  required_version = "~> 0.12.12"
}

/*
  https://www.terraform.io/docs/configuration/providers.html#provider-versions
  https://github.com/terraform-providers/terraform-provider-aws/blob/master/CHANGELOG.md
*/
provider "aws" {
  region = "eu-central-1"
  assume_role {
    role_arn = "arn:aws:iam::621413642706:role/OrganizationAccountAccessRole"
  }
}
provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::621413642706:role/OrganizationAccountAccessRole"
  }
}