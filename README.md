<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 3.22 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 3.22 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account\_id | The AWS account that the CodeBuild project will be created in | `number` | `null` | no |
| artifacts | Build project's primary output artifacts configuration<br>see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference | <pre>object({<br>    type                   = string<br>    artifact_identifier    = optional(string)<br>    encryption_disabled    = optional(bool)<br>    override_artifact_name = optional(bool)<br>    location               = optional(string)<br>    name                   = optional(string)<br>    namespace_type         = optional(string)<br>    packaging              = optional(string)<br>    path                   = optional(string)<br><br>  })</pre> | n/a | yes |
| assumable\_role\_arns | AWS role ARNs the CodeBuild project is allowed to assume | `list(string)` | `[]` | no |
| build\_source | Source configuration that will be loaded into the CodeBuild project's buildspec<br>see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference | <pre>object({<br>    type = string<br>    auth = optional(object({<br>      type     = optional(string)<br>      resource = optional(string)<br>    }))<br>    buildspec       = optional(string)<br>    git_clone_depth = optional(string)<br>    git_submodules_config = optional(object({<br>      fetch_submodules = bool<br>    }))<br>    insecure_ssl        = optional(bool)<br>    location            = optional(string)<br>    report_build_status = optional(bool)<br>  })</pre> | n/a | yes |
| build\_tags | Tags to attach to the CodeBuild project | `map(any)` | `{}` | no |
| build\_timeout | Minutes till build run is timed out | `string` | `null` | no |
| cache | Build project's cache storage configurations | <pre>object({<br>    type     = optional(string)<br>    location = optional(string)<br>    modes    = optional(list(string))<br>  })</pre> | `{}` | no |
| codepipeline\_artifact\_bucket\_name | Associated Codepipeline artifact bucket name | `string` | `null` | no |
| common\_tags | Tags to add to all resources | `map(string)` | `{}` | no |
| create\_source\_auth | Determines if a CodeBuild source credential resource should be created. Only one credential<br>resource is needed/allowed per AWS account and region. See more at: https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_codebuild.GitHubSourceCredentials.html | `bool` | `false` | no |
| cw\_group\_name | CloudWatch group name | `string` | `null` | no |
| cw\_logs | Determines if CloudWatch logs should be enabled | `bool` | `true` | no |
| cw\_stream\_name | CloudWatch stream name | `string` | `null` | no |
| description | CodeBuild project description | `string` | `null` | no |
| environment | Build project's environment configurations<br>see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference | <pre>object({<br>    compute_type                = string<br>    image                       = string<br>    type                        = string<br>    image_pull_credentials_type = optional(string)<br>    environment_variables = optional(list(object({<br>      name  = optional(string)<br>      value = optional(string)<br>      type  = optional(string)<br>    })))<br>    privileged_mode = optional(bool)<br>    certificate     = optional(string)<br>    registry_credential = optional(object({<br>      credential          = string<br>      credential_provider = string<br>    }))<br>  })</pre> | n/a | yes |
| name | Build name (used also for codebuild policy name) | `string` | n/a | yes |
| region | AWS region where the Codebuild project should reside | `string` | `null` | no |
| role\_arn | Existing IAM role ARN to attach to CodeBuild project | `string` | `null` | no |
| role\_description | Build IAM role description | `string` | `"Allows CodeBuild service to perform actions on your behalf"` | no |
| role\_force\_detach\_policies | Determines attached policies to the CodeBuild service roles should be forcefully detached if the role is destroyed | `bool` | `false` | no |
| role\_max\_session\_duration | Max session duration (seconds) the role can be assumed for | `number` | `3600` | no |
| role\_path | Path to create policy | `string` | `"/"` | no |
| role\_permissions\_boundary | Permission boundary policy ARN used for CodeBuild service role | `string` | `""` | no |
| role\_policy\_arns | List of IAM policy ARNs to attach to the role | `list(string)` | `[]` | no |
| role\_policy\_statements | IAM policy statements to attach CodeBuild role policy | <pre>list(object({<br>    sid       = optional(string)<br>    effect    = string<br>    actions   = list(string)<br>    resources = list(string)<br>  }))</pre> | `[]` | no |
| role\_tags | Tags to add to CodeBuild service role | `map(string)` | `{}` | no |
| s3\_log\_bucket | Name of S3 bucket where the build project's logs will be stored | `string` | `null` | no |
| s3\_log\_encryption\_disabled | Determines if encryption should be disabled for the build project's S3 logs | `bool` | `false` | no |
| s3\_log\_key | Bucket path where the build project's logs will be stored (don't include bucket name) | `string` | `null` | no |
| s3\_logs | Determines if S3 logs should be enabled | `bool` | `false` | no |
| secondary\_artifacts | Build project's secondary output artifacts configuration | `map(any)` | `null` | no |
| secondary\_build\_source | Secondary Source configurations.<br>see for more info: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#argument-reference<br>`source_version` attribute is a separate configuration block within `aws_codebuild_project` but is added here since both blocks are similar. | <pre>object({<br>    source_identifier = optional(string)<br>    type              = optional(string)<br>    auth = optional(object({<br>      type     = optional(string)<br>      resource = optional(string)<br>    }))<br>    buildspec       = optional(string)<br>    git_clone_depth = optional(string)<br>    git_submodules_config = optional(object({<br>      fetch_submodules = bool<br>    }))<br>    insecure_ssl        = optional(bool)<br>    location            = optional(string)<br>    report_build_status = optional(bool)<br>    source_version      = optional(string)<br>  })</pre> | `null` | no |
| source\_auth\_server\_type | Source provider type (e.g. `BITBUCKET`, `GITHUB`) | `string` | `null` | no |
| source\_auth\_ssm\_param\_name | AWS SSM Parameter Store key used to retrieve the CodeBuild source credential resource token value | `string` | `null` | no |
| source\_auth\_token | App password (Bitbucket source) or personal access token (Github/Github Enterprise) | `string` | `null` | no |
| source\_auth\_type | Authentification type to connect source provider) | `string` | `null` | no |
| source\_auth\_user\_name | Source Bitbucket user name (required only for Bitbucket) | `string` | `null` | no |
| source\_version | The version of the source input to be delivered to the build. Default to latest | `string` | `null` | no |
| vpc\_config | AWS VPC associated with CodeBuild project | <pre>object({<br>    vpc_id             = string<br>    subnets            = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |
| webhook\_filter\_groups | Webhook filter groups to apply to the build | <pre>list(list(object({<br>    pattern                 = string<br>    type                    = string<br>    exclude_matched_pattern = optional(bool)<br>  })))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | ARN of the CodeBuild project |
| name | Name of the CodeBuild project |
| role\_arn | IAM role for the CodeBuild projec |
| source\_cred\_arn | ARN of the CodeBuild source credential resource |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->