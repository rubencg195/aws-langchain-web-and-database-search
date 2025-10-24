# Configure the AWS Provider
provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}
