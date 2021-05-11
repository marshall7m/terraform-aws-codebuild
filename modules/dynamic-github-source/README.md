<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | 0.15.0 |
| aws | >= 2.23 |
| github | >= 4.4.0 |

## Providers

| Name | Version |
|------|---------|
| archive | n/a |
| aws | >= 2.23 |
| local | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account\_id | AWS account id | `number` | `null` | no |
| api\_description | Description for API-Gateway | `string` | `null` | no |
| api\_name | Name of API-Gateway | `string` | `"custom-github-webhook"` | no |
| codebuild\_artifacts | Build project's primary output artifacts configuration<br>see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference | <pre>object({<br>    type                   = optional(string)<br>    artifact_identifier    = optional(string)<br>    encryption_disabled    = optional(bool)<br>    override_artifact_name = optional(bool)<br>    location               = optional(string)<br>    name                   = optional(string)<br>    namespace_type         = optional(string)<br>    packaging              = optional(string)<br>    path                   = optional(string)<br>  })</pre> | `{}` | no |
| codebuild\_assumable\_role\_arns | List of IAM role ARNS the Codebuild project can assume | `list(string)` | `[]` | no |
| codebuild\_buildspec | Content of the default buildspec file | `string` | `null` | no |
| codebuild\_cache | Cache configuration for Codebuild project | <pre>object({<br>    type     = optional(string)<br>    location = optional(string)<br>    modes    = optional(list(string))<br>  })</pre> | `{}` | no |
| codebuild\_cw\_group\_name | CloudWatch group name | `string` | `null` | no |
| codebuild\_cw\_logs | Determines if CloudWatch logs should be enabled | `bool` | `true` | no |
| codebuild\_cw\_stream\_name | CloudWatch stream name | `string` | `null` | no |
| codebuild\_description | CodeBuild project description | `string` | `null` | no |
| codebuild\_environment | Codebuild environment configuration | <pre>object({<br>    compute_type                = optional(string)<br>    image                       = optional(string)<br>    type                        = optional(string)<br>    image_pull_credentials_type = optional(string)<br>    environment_variables = optional(list(object({<br>      name  = string<br>      value = string<br>      type  = optional(string)<br>    })))<br>    privileged_mode = optional(bool)<br>    certificate     = optional(string)<br>    registry_credential = optional(object({<br>      credential          = optional(string)<br>      credential_provider = optional(string)<br>    }))<br>  })</pre> | `{}` | no |
| codebuild\_name | Name of Codebuild project | `string` | n/a | yes |
| codebuild\_role\_arn | Existing IAM role ARN to attach to CodeBuild project | `string` | `null` | no |
| codebuild\_s3\_log\_bucket | Name of S3 bucket where the build project's logs will be stored | `string` | `null` | no |
| codebuild\_s3\_log\_encryption\_disabled | Determines if encryption should be used for the build project's S3 logs | `bool` | `false` | no |
| codebuild\_s3\_log\_key | Bucket path where the build project's logs will be stored (don't include bucket name) | `string` | `null` | no |
| codebuild\_secondary\_artifacts | Build project's secondary output artifacts configuration | <pre>object({<br>    type                   = optional(string)<br>    artifact_identifier    = optional(string)<br>    encryption_disabled    = optional(bool)<br>    override_artifact_name = optional(bool)<br>    location               = optional(string)<br>    name                   = optional(string)<br>    namespace_type         = optional(string)<br>    packaging              = optional(string)<br>    path                   = optional(string)<br>  })</pre> | `{}` | no |
| codebuild\_tags | Tags to attach to Codebuild project | `map(string)` | `{}` | no |
| codebuild\_timeout | Minutes till build run is timed out | `string` | `null` | no |
| common\_tags | Tags to add to all resources | `map(string)` | `{}` | no |
| create\_github\_secret\_ssm\_param | Determines if a SSM parameter should be created for github webhook secret | `bool` | `false` | no |
| enable\_codebuild\_s3\_logs | Determines if S3 logs should be enabled | `bool` | `false` | no |
| enabled | Determines if module should create resources or destroy pre-existing resources managed by this module | `bool` | `true` | no |
| function\_name | Name of AWS Lambda function | `string` | `"custom-codebuild-github-webhook-trigger"` | no |
| github\_secret\_ssm\_description | Github secret SSM parameter description | `string` | `"Secret value for Github Webhooks"` | no |
| github\_secret\_ssm\_key | SSM parameter store key for github webhook secret. Secret used within Lambda function for Github payload validation. | `string` | `"github-webhook-secret"` | no |
| github\_secret\_ssm\_tags | Tags for Github webhook secret SSM parameter | `map(string)` | `{}` | no |
| github\_secret\_ssm\_value | SSM parameter store value for github webhook secret. Secret used within Lambda function for Github payload validation. | `string` | `""` | no |
| github\_token | Github Personal access token | `string` | `null` | no |
| github\_token\_ssm\_description | Github token SSM parameter description | `string` | `"Github token to allow CodeBuild to clone target repos"` | no |
| github\_token\_ssm\_key | AWS SSM Parameter Store key used to retrieve or create the sensitive Github personal token to allow Codebuild project to clone target Github repos | `string` | `"github-token-codebuild-clone-access"` | no |
| github\_token\_ssm\_tags | Tags for Github token SSM parameter | `map(string)` | `{}` | no |
| github\_token\_ssm\_value | Registered Github webhook token associated with the Github provider. If not provided, module looks for pre-existing SSM parameter via `github_token_ssm_key` | `string` | `""` | no |
| repos | List of named repos to create github webhooks for and their respective filter groups used to select<br>what type of activity will trigger the associated Codebuild.<br>Params:<br>  `name`: Repository name<br>  `codebuild_cfg`: CodeBuild configurations specifically for the repository<br>  `filter_groups`: {<br>    `events` - List of Github Webhook events that will invoke the API. Currently only supports: `push` and `pull_request`.<br>    `pr_actions` - List of pull request actions (e.g. opened, edited, reopened, closed). See more under the action key at: https://docs.github.com/en/developers/webhooks-and-events/webhook-events-and-payloads#pull_request<br>    `base_refs` - List of base refs<br>    `head_refs` - List of head refs<br>    `actor_account_ids` - List of Github user IDs<br>    `commit_messages` - List of commit messages<br>    `file_paths` - List of file paths<br>    `exclude_matched_filter` - If set to true, Codebuild project will not be triggered by this filter if it is matched<br>  } | <pre>list(object({<br>    name = string<br><br>    codebuild_cfg = optional(object({<br>      buildspec = optional(string)<br>      timeout   = optional(string)<br>      cache = optional(object({<br>        type     = optional(string)<br>        location = optional(string)<br>        modes    = optional(list(string))<br>      }))<br>      report_build_status = optional(bool)<br>      environment_type    = optional(string)<br>      compute_type        = optional(string)<br>      image               = optional(string)<br>      environment_variables = optional(list(object({<br>        name  = string<br>        value = string<br>        type  = optional(string)<br>      })))<br>      privileged_mode = optional(bool)<br>      certificate     = optional(string)<br>      artifacts = optional(object({<br>        type                   = optional(string)<br>        artifact_identifier    = optional(string)<br>        encryption_disabled    = optional(bool)<br>        override_artifact_name = optional(bool)<br>        location               = optional(string)<br>        name                   = optional(string)<br>        namespace_type         = optional(string)<br>        packaging              = optional(string)<br>        path                   = optional(string)<br>      }))<br>      secondary_artifacts = optional(object({<br>        type                   = optional(string)<br>        artifact_identifier    = optional(string)<br>        encryption_disabled    = optional(bool)<br>        override_artifact_name = optional(bool)<br>        location               = optional(string)<br>        name                   = optional(string)<br>        namespace_type         = optional(string)<br>        packaging              = optional(string)<br>        path                   = optional(string)<br>      }))<br>      role_arn = optional(string)<br>      logs_cfg = optional(object({<br>        cloudWatchLogs = optional(object({<br>          status     = string<br>          groupName  = string<br>          streamName = string<br>        }))<br>        s3Logs = optional(object({<br>          status   = string<br>          location = string<br>        }))<br>      }))<br>    }))<br><br>    filter_groups = list(list(object({<br>      events                 = optional(list(string))<br>      pr_actions             = optional(list(string))<br>      base_refs              = optional(list(string))<br>      head_refs              = optional(list(string))<br>      actor_account_ids      = optional(list(string))<br>      commit_messages        = optional(list(string))<br>      file_paths             = optional(list(string))<br>      exclude_matched_filter = optional(bool)<br>    })))<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_invoke\_url | n/a |
| codebuild\_arn | n/a |
| github\_token\_ssm\_key | n/a |
| payload\_filter\_function\_arn | n/a |
| payload\_validator\_function\_arn | n/a |
| repo\_cfg | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
