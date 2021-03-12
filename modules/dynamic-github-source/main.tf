locals {
  codebuild_artifacts = defaults(var.codebuild_artifacts, {
    type = "NO_ARTIFACTS"
  })
  # codebuild_environment = defaults(var.codebuild_environment, {
  #   compute_type = "BUILD_GENERAL1_SMALL"
  #   type = "LINUX_CONTAINER"
  #   image = "aws/codebuild/standard:3.0"
  # })
}

module "github_webhook" {
  source = "github.com/marshall7m/terraform-aws-lambda/modules//agw-github-webhook"

  api_name = var.api_name
  api_description = var.api_description
  repo_queries = [for entry in var.queried_repos: 
    {
      query = entry.query 
      events = [for filter in flatten(entry.filter_groups): filter.pattern if filter.type == "event"]
    }
  ]
  repos = [for repo in var.named_repos: 
    {
      name = repo.name 
      events = [for filter in flatten(repo.filter_groups): filter.pattern if filter.type == "event"]
    }
  ]
  github_secret_ssm_key = var.github_secret_ssm_key
  github_secret_ssm_value = var.github_secret_ssm_value
  github_secret_ssm_description = var.github_secret_ssm_description
  github_secret_ssm_tags = var.github_secret_ssm_tags
  child_function_arn = module.lambda.function_arn
}

module "lambda" {
  source           = "github.com/marshall7m/terraform-aws-lambda/modules//function"
  filename         = data.archive_file.lambda_function.output_path
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  function_name    = var.function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  enable_cw_logs = true
  env_vars = {
    GITHUB_TOKEN_SSM_KEY = var.github_token_ssm_key
    # FILTER_GROUPS = jsonencode({for repo in module.github_webhook.repos: repo.name => repo.filter_groups})
    CODEBUILD_NAME = module.codebuild.name
  }
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.lambda.arn
  ]
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "GithubWebhookTokenReadAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [try(aws_ssm_parameter.github_token[0].arn, data.aws_ssm_parameter.github_token[0].arn)]
  }

  statement {
    sid = "TriggerCodeBuild"
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
  source = "..//main"
  name = var.codebuild_name
  artifacts = local.codebuild_artifacts
  # environment = local.codebuild_environment
  environment = {
    compute_type = "BUILD_GENERAL1_SMALL"
    type = "LINUX_CONTAINER"
    image = "aws/codebuild/standard:3.0"
  }
  build_source = {
    type = "GITHUB"
    auth = {
      type = "OAUTH"
    }
    report_build_status = true
  }
}

resource "aws_ssm_parameter" "github_token" {
  count       = var.github_token_ssm_value != "" ? 1 : 0
  name        = var.github_token_ssm_key
  description = var.github_token_ssm_description
  type        = "SecureString"
  value       = var.github_token_ssm_value
  tags = var.github_token_ssm_tags
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