terraform {
  required_version = "0.15.0"
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
    testing = {
      source = "apparentlymart/testing"
      version = "0.0.2"
    }
    github = {
        source = "integrations/github"
        version = "4.5.2"
    }
  }
}

locals {
    mut = basename(path.cwd)
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

resource "github_repository_file" "test" {
  repository          = github_repository.test.name
  branch              = "master"
  file                = "test_two.txt"
  content             = "used to trigger repo's webhook for testing associated mut: ${local.mut}"
  commit_message      = "test file"
  overwrite_on_create = true
  depends_on = [
    module.mut_dynamic_github_source
  ]
}

module "mut_dynamic_github_source" {
    source = "../../modules//dynamic-github-source"
    create_github_secret_ssm_param = true
    github_secret_ssm_value = random_password.this.result
    github_token_ssm_value = var.github_token
    codebuild_name = "${local.mut}-${random_id.default.id}"
    build_source = {
      type = "NO_SOURCE"
      buildspec = file("${path.module}/buildspec.yaml")
      report_build_status = true
    }
    repos = [
        {
            name = github_repository.test.name
            filter_groups = [
                [
                    {
                        type = "event"
                        pattern = "push"
                    },
                    {
                        type = "file_path"
                        pattern = "CHANGELOG.md"
                    }
                ],
                [
                    {
                        type = "event"
                        pattern = "push"
                    },
                    {
                        type = "file_path"
                        pattern = "\\/?.?\\.txt$"
                    }
                ]
            ]
        }
    ]
    depends_on = [
      github_repository.test
    ]
}