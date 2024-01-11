# Use this module cimply copy and paste it into the main.tf file and it will automatically initilaize the backend process by the terraform init command. 


module "codepipeline" {
  source = "git::https://github.com/sp2001singh/codepipeline-module.git"
 
  region                  = "us-east-1"
  #code Commit repo name
  repo_name               = "cicd-tf-test"
  tag_name_for_codedeploy = "cicd-test-App"
 
  # name of the ecr repo
  name = "shiv-ecr-repo"
 
  # Tags
  tags = {
    Owner       = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }
}
 
