# Terraform CodePipeline Module

This repository contains Terraform code to provision and manage AWS resources for a CI/CD pipeline using CodePipeline, CodeCommit, CodeBuild, CodeDeploy, ECR, and other related services.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Terraform Modules](#terraform-modules)
- [Usage](#usage)
- [Variables](#variables)
- [Outputs](#outputs)


## Prerequisites

Before using this Terraform code, make sure you have the following prerequisites:

- AWS CLI configured with appropriate credentials
- Terraform installed (version x.x.x)

## Directory Structure

.
├── modules/
│ ├── <module1>/
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ └── outputs.tf
│ ├── <module2>/
│ │ └── ...
├── policies/
│ ├── codebuild_assume_role.json
│ ├── codebuild.json
│ ├── codepipeline.json
│ └── ...
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
└── ...


- **`modules/`**: Contains reusable Terraform modules for different components.
- **`policies/`**: Holds JSON files defining IAM policies used in the code.
- **`main.tf`**: Main Terraform configuration file.
- **`variables.tf`**: Declares input variables.
- **`outputs.tf`**: Defines output values.

## Terraform Modules

The Terraform code is organized into modules for better maintainability and reusability. Each module encapsulates a specific AWS resource or set of related resources.

### Module 1: CodePipeline

The `aws_codepipeline` module sets up a CodePipeline to automate the CI/CD process.

### Module 2: ECR Repository

The `aws_ecr_repository` module creates an Elastic Container Registry (ECR) repository with optional settings.

...

## Usage

To deploy the infrastructure, follow these steps:

1. Create a file main.tf indside a new directory
2. Paste the below terraform module code snippet 
3. Run the command `terraform init`
4. Run the command `terraform plan`
5. Run the command `terraform apply -auto-approve`
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





