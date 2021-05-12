locals {
  codebuild_artifacts = defaults(var.codebuild_artifacts, {
    type = "NO_ARTIFACTS"
  })
  codebuild_environment = defaults(var.codebuild_environment, {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/standard:3.0"
  })
  default_repos = [for repo in var.repos : merge(repo, {
    filter_groups = [for filter_group in repo.filter_groups :
      defaults(filter_group, {
        exclude_matched_filter = false
      })
    ]
  })]

  codebuild_override_keys = {
    buildspec             = "buildspecOverride"
    timeout               = "timeoutInMinutesOverride"
    cache                 = "cacheOverride"
    privileged_mode       = "privilegedModeOverride"
    report_build_status   = "reportBuildStatusOverride"
    environment_type      = "environmentTypeOverride"
    compute_type          = "computeTypeOverride"
    image                 = "imageOverride"
    environment_variables = "environmentVariablesOverride"
    artifacts             = "artifactsOverride"
    secondary_artifacts   = "secondaryArtifactsOverride"
    role_arn              = "serviceRoleOverride"
    logs_cfg              = "logsConfigOverride"
    certificate           = "certificateOverride"
  }
  repos = [for repo in local.default_repos : merge(repo, {
    #pulls distinct filter group events to define the Github webhook events
    events = distinct(flatten([for filter_group in repo.filter_groups :
    filter_group.events if filter_group.exclude_matched_filter != true]))
    #converts terraform codebuild params to python boto3 start_build() params
    codebuild_cfg = repo.codebuild_cfg != null ? { for key in keys(repo.codebuild_cfg) : local.codebuild_override_keys[key] => lookup(repo.codebuild_cfg, key) if lookup(repo.codebuild_cfg, key) != null } : null
  })]
}

module "github_webhook" {
  source = "github.com/marshall7m/terraform-aws-lambda/modules//agw-github-webhook"

  api_name        = var.api_name
  api_description = var.api_description
  repos = [for repo in local.repos : {
    name   = repo.name
    events = repo.events
  }]
  create_github_secret_ssm_param  = var.create_github_secret_ssm_param
  github_secret_ssm_key           = var.github_secret_ssm_key #tfsec:ignore:GEN003
  github_secret_ssm_value         = var.github_secret_ssm_value
  github_secret_ssm_description   = var.github_secret_ssm_description #tfsec:ignore:GEN003
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
  source = "..//main"

  name        = var.codebuild_name
  description = var.codebuild_description

  assumable_role_arns = var.codebuild_assumable_role_arns
  artifacts           = local.codebuild_artifacts
  environment         = local.codebuild_environment
  build_timeout       = var.codebuild_timeout
  cache               = var.codebuild_cache
  secondary_artifacts = var.codebuild_secondary_artifacts
  build_source = {
    buildspec = coalesce(var.codebuild_buildspec, file("${path.module}/buildspec_placeholder.yaml"))
    type      = "NO_SOURCE"
  }

  s3_logs                    = var.enable_codebuild_s3_logs
  s3_log_key                 = var.codebuild_s3_log_key
  s3_log_bucket              = var.codebuild_s3_log_bucket
  s3_log_encryption_disabled = var.codebuild_s3_log_encryption
  cw_logs                    = var.codebuild_cw_logs
  cw_group_name              = var.codebuild_cw_group_name
  cw_stream_name             = var.codebuild_cw_stream_name
  role_arn                   = var.codebuild_role_arn
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
  content = jsonencode({ for repo in local.repos :
    repo.name => {
      events        = repo.events
      filter_groups = repo.filter_groups
      codebuild_cfg = repo.codebuild_cfg
    }
  })
  filename = "${path.module}/deps/repo_cfg.json"
}

data "archive_file" "lambda_deps" {
  type        = "zip"
  source_dir  = "${path.module}/deps"
  output_path = "${path.module}/lambda_deps.zip"
  depends_on  = [local_file.filter_groups]
}
