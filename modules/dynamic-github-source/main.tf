locals {
  codebuild_artifacts = defaults(var.codebuild_artifacts, {
    type = "NO_ARTIFACTS"
  })
  codebuild_environment = defaults(var.codebuild_environment, {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/standard:3.0"
  })

  repos = [for repo in var.repos : merge(
    [for filter_group in repo.filter_groups :
      [for filter in filter_group :
        defaults(filter, {
          events                 = ""
          pr_actions             = ""
          base_refs              = ""
          head_refs              = ""
          actor_account_ids      = ""
          commit_messages        = ""
          file_paths             = ""
          exclude_matched_filter = false
        })
      ]
    ], repo)
  ]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

module "github_webhook" {
  source = "github.com/marshall7m/terraform-aws-lambda/modules//agw-github-webhook"

  api_name        = var.api_name
  api_description = var.api_description
  repos = [for repo in var.repos :
    {
      name = repo.name
      events = distinct(flatten([for filter in flatten(repo.filter_groups) :
      filter.events if filter.exclude_matched_filter != true]))
    }
  ]
  create_github_secret_ssm_param  = var.create_github_secret_ssm_param
  github_secret_ssm_key           = var.github_secret_ssm_key
  github_secret_ssm_value         = var.github_secret_ssm_value
  github_secret_ssm_description   = var.github_secret_ssm_description
  github_secret_ssm_tags          = var.github_secret_ssm_tags
  lambda_success_destination_arns = [module.lambda.function_arn]
  async_lambda_invocation         = true
}

module "lambda" {
  source           = "github.com/marshall7m/terraform-aws-lambda/modules//function"
  filename         = data.archive_file.lambda_function.output_path
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  function_name    = var.function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  enable_cw_logs   = true
  env_vars = {
    GITHUB_TOKEN_SSM_KEY = var.github_token_ssm_key
    CODEBUILD_NAME       = module.codebuild.name
  }
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.lambda.arn
  ]
  lambda_layers = [
    {
      filename         = data.archive_file.lambda_deps.output_path
      name             = "${var.function_name}-deps"
      runtimes         = ["python3.8"]
      source_code_hash = data.archive_file.lambda_deps.output_base64sha256
      description      = "Dependencies for lambda function: ${var.function_name}"
    }
  ]
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "GithubWebhookTokenReadAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [try(aws_ssm_parameter.github_token[0].arn, data.aws_ssm_parameter.github_token[0].arn)]
  }

  statement {
    sid    = "TriggerCodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:StartBuildBatch",
      "codebuild:UpdateProject"
    ]
    resources = [module.codebuild.arn]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = var.function_name
  policy = data.aws_iam_policy_document.lambda.json
}

module "codebuild" {
  source       = "..//main"
  name         = var.codebuild_name
  artifacts    = local.codebuild_artifacts
  environment  = local.codebuild_environment
  build_source = var.build_source
}

resource "aws_ssm_parameter" "github_token" {
  count       = var.github_token_ssm_value != "" ? 1 : 0
  name        = var.github_token_ssm_key
  description = var.github_token_ssm_description
  type        = "SecureString"
  value       = var.github_token_ssm_value
  tags        = var.github_token_ssm_tags
}

data "aws_ssm_parameter" "github_token" {
  count = var.github_token_ssm_value == "" ? 1 : 0
  name  = var.github_token_ssm_key
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

#using lambda layer file for filter_groups given lambda functions have a size limit of 4KB for env vars
resource "local_file" "filter_groups" {
  content  = jsonencode({ for repo in local.repos : repo.name => repo.filter_groups })
  filename = "${path.module}/deps/filter_groups.json"
}

data "archive_file" "lambda_deps" {
  type        = "zip"
  source_dir  = "${path.module}/deps"
  output_path = "${path.module}/lambda_deps.zip"
  depends_on  = [local_file.filter_groups]
}

data "github_user" "current" {
  username = ""
}