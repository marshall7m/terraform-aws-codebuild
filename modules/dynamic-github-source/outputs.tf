output "api_invoke_url" {
  value = module.github_webhook.invoke_url
}

output "payload_validator_function_arn" {
  value = module.github_webhook.function_arn
}

output "payload_filter_function_arn" {
  value = module.lambda.function_arn
}

output "github_token_ssm_key" {
  value = var.github_token_ssm_key
}

output "codebuild_arn" {
  value = module.codebuild.arn
}