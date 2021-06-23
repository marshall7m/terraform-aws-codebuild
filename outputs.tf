output "arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.this.arn
}

output "name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.this.name
}

output "role_arn" {
  description = "IAM role for the CodeBuild projec"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "source_cred_arn" {
  description = "ARN of the CodeBuild source credential resource"
  value       = try(aws_codebuild_source_credential.this[0].arn, null)
}