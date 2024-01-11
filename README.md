# Terraform CodePipeline Module

Use this module by simply copying and pasting it into the main.tf file. It will automatically initialize the backend process by the `terraform init` command.

```hcl
module "codepipeline" {
  source = "git::https://github.com/sp2001singh/codepipeline-module.git"

  region                  = "us-east-1"
  # CodeCommit repo name
  repo_name               = "cicd-tf-test"
  tag_name_for_codedeploy = "cicd-test-App"

  # Name of the ECR repo
  name = "shiv-ecr-repo"

  # Tags
  tags = {
    Owner       = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }
}
