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
  file                = "test.txt"
  content             = "used to trigger repo's webhook for testing associated mut: ${local.mut}"
  commit_message      = "test file"
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
  build_source = {
    type                = "NO_SOURCE"
    buildspec           = file("${path.module}/buildspec.yaml")
    report_build_status = true
  }
  repos = [
    {
      name = github_repository.test.name
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
            events = ["push"]
          },
          {
            file_paths = ["\\.*\\.txt$"]
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

# data "aws_lambda_invocation" "not_sha_signed" {
#   function_name = module.mut_dynamic_github_source.payload_validator_function_arn

#   input = jsonencode(
#     {
#       "headers" = {
#         "X-Hub-Signature-256" = sha256("test")
#         "X-GitHub-Event": "push"
#       }
#       "body" = {}
#     }
#   )
# }

# data "aws_caller_identity" "current" {}

# data "bash_script" "example" {
#   source = <<EOF
#   aws sts assume-role ${aws_caller_identity.current.arn}
#   aws lambda invoke --function-name ${module.mut_dynamic_github_source.payload_validator_function_arn} --payload ${jsonencode(
#     {
#       "headers" = {
#         "X-Hub-Signature-256" = sha256("test")
#         "X-GitHub-Event": "push"
#       }
#       "body" = {}
#     }
#   )}
#   EOF
# }