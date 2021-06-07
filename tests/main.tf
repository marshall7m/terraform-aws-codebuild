locals {
  mut = "mut-codebuild"
}

provider "random" {}

resource "random_password" "this" {
  length = 20
}

resource "random_id" "default" {
  byte_length = 8
}

resource "github_repository" "test" {
  name        = "${local.mut}-${random_id.default.id}"
  description = "Test repo for mut: ${local.mut}"
  auto_init   = true
  visibility  = "public"
}

resource "github_branch" "test" {
  repository    = github_repository.test.name
  branch        = "test-branch"
  source_branch = "master"
}

resource "github_repository_file" "test" {
  repository          = github_repository.test.name
  branch              = github_branch.test.branch
  file                = "test.py"
  content             = "used for testing associated mut: ${local.mut}"
  commit_message      = "test file"
  overwrite_on_create = true
  depends_on = [
    module.mut_codebuild
  ]
}

module "mut_codebuild" {
    source = "..//"
    region = "us-west-2"
    name = "${local.mut}-${random_id.default.id}"
    artifacts = {
        type = "NO_ARTIFACTS"
    }
    common_tags = {"foo" = "bar"}
    environment = {
      type = "LINUX_CONTAINER"
      image = "aws/codebuild/standard:4.0"
      compute_type = "BUILD_GENERAL1_SMALL"
      priviledged_mode = true
      environment_variables = [
        {
          name = "bar"
          value = "foo"
        },
        {
          name = "zoo"
          value = "baz"
          type = "PARAMETER_STORE"
        }
      ]
    }

    build_source = {
      type = "GITHUB"
      location        = github_repository.test.http_clone_url
      buildspec = file("buildspec.yaml")
    }
    cache = {
      type  = "LOCAL"
      modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
    }
    webhook_filter_groups = [
        [
            {
                type = "EVENT"
                pattern = "PUSH"
            }
        ]
    ]
}