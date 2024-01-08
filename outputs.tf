output "artifact_bucket_id" {
  value = aws_s3_bucket.artifact_bucket.id
}

output "artifact_bucket_arn" {
  value = aws_s3_bucket.artifact_bucket.arn
}

output "codebuild_package_id" {
  value = aws_codebuild_project.package.id
}

output "codepipeline_id" {
  value = aws_codepipeline.codepipeline.id
}

output "kms_key_arn" {
  value = aws_kms_key.artifact_key.arn
}

output "repo_https_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_http
}

output "repo_ssh_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_ssh
}

################################################################
# Outputs for the second terraform configuration module integration
#################################################################

output "arn" {
  description = "Full ARN of the repository"
  value       = aws_ecr_repository.repo.arn
}

output "name" {
  description = "The name of the repository."
  value       = aws_ecr_repository.repo.name
}

output "registry_id" {
  description = "The registry ID where the repository was created."
  value       = aws_ecr_repository.repo.registry_id
}

output "repository_url" {
  description = "The URL of the repository (in the form `aws_account_id.dkr.ecr.region.amazonaws.com/repositoryName`)"
  value       = aws_ecr_repository.repo.repository_url

}

