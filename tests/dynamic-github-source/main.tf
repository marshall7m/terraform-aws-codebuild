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

resource "github_repository_file" "test_pr" {
  repository          = github_repository.test.name
  branch              = github_branch.test_pr.branch
  file                = "test.py"
  content             = "used to trigger repo's webhook for testing associated mut: ${local.mut}"
  commit_message      = "test file"
  overwrite_on_create = true
  depends_on = [
    module.mut_dynamic_github_source
  ]
}

resource "github_branch" "test_pr" {
  repository    = github_repository.test.name
  branch        = "test-branch"
  source_branch = "master"
}

resource "github_repository_pull_request" "test_pr" {
  base_repository = github_repository.test.name
  base_ref        = "master"
  head_ref        = github_branch.test_pr.branch
  title           = "Test webhook PR filter"
  body            = "Check Cloudwatch logs for results"
  depends_on      = [github_repository_file.test_pr]
}

resource "github_repository_file" "test_push" {
  repository          = github_repository.test.name
  branch              = "master"
  file                = "CHANGELOG.md"
  content             = "used to trigger repo's webhook for testing associated mut: ${local.mut}"
  commit_message      = "test webhook push filter"
  overwrite_on_create = true
  depends_on = [
    module.mut_dynamic_github_source
  ]
}

module "mut_dynamic_github_source" {
  source                         = "../../modules//dynamic-github-source"
  create_github_secret_ssm_param = true
  github_secret_ssm_value        = random_password.this.result
  github_token_ssm_value         = var.github_token
  codebuild_name                 = "${local.mut}-${random_id.default.id}"

  repos = [
    {
      name = github_repository.test.name
      codebuild_cfg = {
        environment_variables = [
          {
            name  = "TEST"
            value = "FOO"
            type  = "PLAINTEXT"
          }
        ]
      }
      filter_groups = [
        [
          {
            events = ["push"]
          },
          {
            file_paths = ["CHANGELOG.md"]
          }
        ],
        [
          {
            events     = ["pull_request"]
            pr_actions = ["opened", "edited", "synchronize"]
            file_paths = [".*\\.py$"]
            head_refs  = ["test-branch"]
          }
        ]
      ]
    }
  ]
  depends_on = [
    github_repository.test
  ]
}

output "api_invoke_url" {
  value = module.mut_dynamic_github_source.api_invoke_url
}

output "repo_cfg" {
  value = module.mut_dynamic_github_source.repo_cfg
}