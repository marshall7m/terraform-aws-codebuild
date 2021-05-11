variable "enabled" {
  description = "Determines if module should create resources or destroy pre-existing resources managed by this module"
  type        = bool
  default     = true
}

variable "account_id" {
  description = "AWS account id"
  type        = number
  default     = null
}

variable "common_tags" {
  description = "Tags to add to all resources"
  type        = map(string)
  default     = {}
}

# SSM #

## github-token ##

variable "github_token_ssm_description" {
  description = "Github token SSM parameter description"
  type        = string
  default     = "Github token to allow CodeBuild to clone target repos" #tfsec:ignore:GEN001
}

variable "github_token_ssm_key" {
  description = "AWS SSM Parameter Store key used to retrieve or create the sensitive Github personal token to allow Codebuild project to clone target Github repos"
  type        = string
  default     = "github-token-codebuild-clone-access" #tfsec:ignore:GEN001
}

variable "github_token_ssm_value" {
  description = "Registered Github webhook token associated with the Github provider. If not provided, module looks for pre-existing SSM parameter via `github_token_ssm_key`"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_token_ssm_tags" {
  description = "Tags for Github token SSM parameter"
  type        = map(string)
  default     = {}
}

## github-secret ##

variable "create_github_secret_ssm_param" {
  description = "Determines if a SSM parameter should be created for github webhook secret"
  type        = bool
  default     = false
}

variable "github_secret_ssm_key" {
  description = "SSM parameter store key for github webhook secret. Secret used within Lambda function for Github payload validation."
  type        = string
  default     = "github-webhook-secret" #tfsec:ignore:GEN001 #tfsec:ignore:GEN003
}

variable "github_secret_ssm_value" {
  description = "SSM parameter store value for github webhook secret. Secret used within Lambda function for Github payload validation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_secret_ssm_description" {
  description = "Github secret SSM parameter description"
  type        = string
  default     = "Secret value for Github Webhooks" #tfsec:ignore:GEN001 #tfsec:ignore:GEN003
}

variable "github_secret_ssm_tags" {
  description = "Tags for Github webhook secret SSM parameter"
  type        = map(string)
  default     = {}
}

# Github #

variable "repos" {
  description = <<EOF
List of named repos to create github webhooks for and their respective filter groups used to select
what type of activity will trigger the associated Codebuild.
Params:
  `name`: Repository name
  `codebuild_cfg`: CodeBuild configurations specifically for the repository
  `filter_groups`: {
    `events` - List of Github Webhook events that will invoke the API. Currently only supports: `push` and `pull_request`.
    `pr_actions` - List of pull request actions (e.g. opened, edited, reopened, closed). See more under the action key at: https://docs.github.com/en/developers/webhooks-and-events/webhook-events-and-payloads#pull_request
    `base_refs` - List of base refs
    `head_refs` - List of head refs
    `actor_account_ids` - List of Github user IDs
    `commit_messages` - List of commit messages
    `file_paths` - List of file paths
    `exclude_matched_filter` - If set to true, Codebuild project will not be triggered by this filter if it is matched
  }
EOF

  type = list(object({
    name = string

    codebuild_cfg = optional(object({
      buildspec = optional(string)
      timeout   = optional(string)
      cache = optional(object({
        type     = optional(string)
        location = optional(string)
        modes    = optional(list(string))
      }))
      report_build_status = optional(bool)
      environment_type    = optional(string)
      compute_type        = optional(string)
      image               = optional(string)
      environment_variables = optional(list(object({
        name  = string
        value = string
        type  = optional(string)
      })))
      privileged_mode = optional(bool)
      certificate     = optional(string)
      artifacts = optional(object({
        type                   = optional(string)
        artifact_identifier    = optional(string)
        encryption_disabled    = optional(bool)
        override_artifact_name = optional(bool)
        location               = optional(string)
        name                   = optional(string)
        namespace_type         = optional(string)
        packaging              = optional(string)
        path                   = optional(string)
      }))
      secondary_artifacts = optional(object({
        type                   = optional(string)
        artifact_identifier    = optional(string)
        encryption_disabled    = optional(bool)
        override_artifact_name = optional(bool)
        location               = optional(string)
        name                   = optional(string)
        namespace_type         = optional(string)
        packaging              = optional(string)
        path                   = optional(string)
      }))
      role_arn = optional(string)
      logs_cfg = optional(object({
        cloudWatchLogs = optional(object({
          status     = string
          groupName  = string
          streamName = string
        }))
        s3Logs = optional(object({
          status   = string
          location = string
        }))
      }))
    }))

    filter_groups = list(list(object({
      events                 = optional(list(string))
      pr_actions             = optional(list(string))
      base_refs              = optional(list(string))
      head_refs              = optional(list(string))
      actor_account_ids      = optional(list(string))
      commit_messages        = optional(list(string))
      file_paths             = optional(list(string))
      exclude_matched_filter = optional(bool)
    })))
  }))
  default = []
}

# Lambda #

variable "function_name" {
  description = "Name of AWS Lambda function"
  type        = string
  default     = "custom-codebuild-github-webhook-trigger"
}

# Codebuild #

variable "codebuild_name" {
  description = "Name of Codebuild project"
  type        = string
}

variable "codebuild_description" {
  description = "CodeBuild project description"
  type        = string
  default     = null
}

variable "codebuild_assumable_role_arns" {
  description = "List of IAM role ARNS the Codebuild project can assume"
  type        = list(string)
  default     = []
}

variable "codebuild_buildspec" {
  description = "Content of the default buildspec file"
  type        = string
  default     = null
}

variable "codebuild_timeout" {
  description = "Minutes till build run is timed out"
  type        = string
  default     = null
}

variable "codebuild_cache" {
  description = "Cache configuration for Codebuild project"
  type = object({
    type     = optional(string)
    location = optional(string)
    modes    = optional(list(string))
  })
  default = {}
}

variable "codebuild_environment" {
  description = "Codebuild environment configuration"
  type = object({
    compute_type                = optional(string)
    image                       = optional(string)
    type                        = optional(string)
    image_pull_credentials_type = optional(string)
    environment_variables = optional(list(object({
      name  = string
      value = string
      type  = optional(string)
    })))
    privileged_mode = optional(bool)
    certificate     = optional(string)
    registry_credential = optional(object({
      credential          = optional(string)
      credential_provider = optional(string)
    }))
  })
  default = {}
}

variable "github_token" {
  description = "Github Personal access token"
  type        = string
  default     = null
  sensitive   = true
}

variable "codebuild_artifacts" {
  description = <<EOF
Build project's primary output artifacts configuration
see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference
EOF
  type = object({
    type                   = optional(string)
    artifact_identifier    = optional(string)
    encryption_disabled    = optional(bool)
    override_artifact_name = optional(bool)
    location               = optional(string)
    name                   = optional(string)
    namespace_type         = optional(string)
    packaging              = optional(string)
    path                   = optional(string)
  })
  default = {}
}

variable "codebuild_secondary_artifacts" {
  description = "Build project's secondary output artifacts configuration"
  type = object({
    type                   = optional(string)
    artifact_identifier    = optional(string)
    encryption_disabled    = optional(bool)
    override_artifact_name = optional(bool)
    location               = optional(string)
    name                   = optional(string)
    namespace_type         = optional(string)
    packaging              = optional(string)
    path                   = optional(string)
  })
  default = {}
}

variable "enable_codebuild_s3_logs" {
  description = "Determines if S3 logs should be enabled"
  type        = bool
  default     = false
}

variable "codebuild_s3_log_key" {
  description = "Bucket path where the build project's logs will be stored (don't include bucket name)"
  type        = string
  default     = null
}

variable "codebuild_s3_log_bucket" {
  description = "Name of S3 bucket where the build project's logs will be stored"
  type        = string
  default     = null
}

variable "codebuild_s3_log_encryption_disabled" {
  description = "Determines if encryption should be used for the build project's S3 logs"
  type        = bool
  default     = false
}

variable "codebuild_cw_logs" {
  description = "Determines if CloudWatch logs should be enabled"
  type        = bool
  default     = true
}

variable "codebuild_cw_group_name" {
  description = "CloudWatch group name"
  type        = string
  default     = null
}

variable "codebuild_cw_stream_name" {
  description = "CloudWatch stream name"
  type        = string
  default     = null
}

variable "codebuild_role_arn" {
  description = "Existing IAM role ARN to attach to CodeBuild project"
  type        = string
  default     = null
}

variable "codebuild_tags" {
  description = "Tags to attach to Codebuild project"
  type        = map(string)
  default     = {}
}

# AGW #

variable "api_name" {
  description = "Name of API-Gateway"
  type        = string
  default     = "custom-github-webhook"
}

variable "api_description" {
  description = "Description for API-Gateway"
  type        = string
  default     = null
}