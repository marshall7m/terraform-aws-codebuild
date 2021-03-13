terraform {
  required_version = "0.14.8"
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
    testing = {
      source = "apparentlymart/testing"
      version = "0.0.2"
    }
  }
}

variable "github_token" {
    type = string
    sensitive = true
}

variable "github_secret_ssm_value" {
    type = string
    sensitive = true
}

module "dynamic_codebuild" {
    source = "../../modules//dynamic-github-source"
    github_secret_ssm_value = var.github_secret_ssm_value
    github_token_ssm_value = var.github_token
    named_repos = [
        {
            name = "terraform-aws-codebuild"
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
                        pattern = "pull_request"
                    },
                    {
                        type = "file_path"
                        pattern = "\\/.?\\.tf$"
                    }
                ]
            ]
        }
    ]
    queried_repos = [
        {
            query = "foo in:name"
            filter_groups = [
                [
                    {
                        type = "event"
                        pattern = "pull_request"
                    }
                ]
            ]
        }
    ]
}