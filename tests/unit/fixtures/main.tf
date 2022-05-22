provider "random" {}

resource "random_password" "this" {
  length = 20
}

resource "random_id" "default" {
  byte_length = 8
}

module "mut_codebuild" {
  source = "../../..//"
  region = "us-west-2"
  name   = "mut-terraform-aws-codebuild-${random_id.default.id}"
  artifacts = {
    type = "NO_ARTIFACTS"
  }
  environment = {
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/standard:4.0"
    compute_type = "BUILD_GENERAL1_SMALL"
  }

  build_source = {
    type      = "NO_SOURCE"
    buildspec = "echo foo"
  }
}