provider "aws" {
  region = var.region
}

data "aws_region" "current" {}

# Random UUID
resource "random_uuid" "id" {}

# CodeCommit Resources
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repo_name
  description     = "${var.repo_name} repository"
  default_branch  = var.repo_default_branch
}

# CodeDeploy Resources
# CodeDeploy Assume Role and Policy Attachment
data "aws_iam_policy_document" "codedeploy_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_policy_document.json
}

resource "aws_iam_role_policy_attachment" "codedeploy_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
}

resource "aws_codedeploy_app" "codedeploy" {
  name = var.repo_name
}

resource "aws_codedeploy_deployment_group" "codedeploy_dg" {
  app_name               = aws_codedeploy_app.codedeploy.name
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_group_name  = "${var.repo_name}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  # autoscaling_groups     = var.asg_groups

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = var.tag_name_for_codedeploy
    }
  }

}

# CodeBuild IAM Permissions
data "template_file" "codepipeline_assume_role_template" {
  template = file("${path.module}/policies/codebuild_assume_role.json")
}

resource "aws_iam_role" "codebuild_assume_role" {
  name               = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codebuild-role"
  assume_role_policy = data.template_file.codepipeline_assume_role_template.rendered
}

# CodeBuild Policy Template
data "template_file" "codebuild_policy_template" {
  template = file("${path.module}/policies/codebuild.json")
  vars = {
    artifact_bucket           = aws_s3_bucket.artifact_bucket.arn
    aws_kms_key               = aws_kms_key.artifact_key.arn
    codebuild_project_package = aws_codebuild_project.package.id
  }
}

# CodeBuild Role Policy
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codebuild-policy"
  role = aws_iam_role.codebuild_assume_role.id

  policy = data.template_file.codebuild_policy_template.rendered
}

# CodeBuild - Package
resource "aws_codebuild_project" "package" {
  name           = "${var.repo_name}-package"
  description    = "CodeBuild Package Project for ${var.repo_name}"
  service_role   = aws_iam_role.codebuild_assume_role.arn
  build_timeout  = var.build_timeout
  encryption_key = aws_kms_key.artifact_key.arn

  artifacts {
    packaging = "ZIP"
    type      = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.build_privileged
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.package_buildspec
  }
}

# Codepipeline Resources
# S3 bucket for Artifact storage
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}"
  acl           = "private"
  force_destroy = var.force_artifact_destroy
}

# Policy Document for CodePipeline Assume Role
data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

# IAM for CodePipeline with previously defined policy document
resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
}

# IAM Policy Template for CodePipeline to use CodeCommit and CodeBuild
data "template_file" "codepipeline_policy_template" {
  template = file("${path.module}/policies/codepipeline.json")
  vars = {
    aws_kms_key     = aws_kms_key.artifact_key.arn
    artifact_bucket = aws_s3_bucket.artifact_bucket.arn
  }
}

# Attach Policy Document for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy_attach" {
  name = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = data.template_file.codepipeline_policy_template.rendered
}

########################################
# New Policy attachnment for the ecr access to codebuild and codepipeline
########################################

# IAM Policy for ECR access
resource "aws_iam_policy" "ecr_full_access_policy" {
  name        = "ecr-full-access-policy"
  description = "Policy for ECR full access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach ECR policy to CodeBuild role
resource "aws_iam_policy_attachment" "codebuild_ecr_policy_attachment" {
  name       = "codebuild-ecr-policy-attachment"
  roles      = [aws_iam_role.codebuild_assume_role.name]
  policy_arn = aws_iam_policy.ecr_full_access_policy.arn
}

# Attach ECR policy to CodePipeline role
resource "aws_iam_policy_attachment" "codepipeline_ecr_policy_attachment" {
  name       = "codepipeline-ecr-policy-attachment"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.ecr_full_access_policy.arn
}



####################################
###################################


# Encryption key for artifacts
resource "aws_kms_key" "artifact_key" {
  description             = "kms-artifact-encryption-key"
  deletion_window_in_days = 10
}

# SNS URL
resource "aws_sns_topic" "approval" {
  name = "${var.repo_name}-deployment-approval"
}

# CloudWatch Events Trigger
resource "aws_cloudwatch_event_rule" "pipeline_state_update" {
  name        = "${var.repo_name}-pipeline-updated"
  description = "Capture state chanages in CodeCommit for ${var.repo_name}"

  event_pattern = <<EOF
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": ["${aws_codecommit_repository.repo.arn}"],
  "detail": {
    "referenceType": ["branch"],
    "referenceName": ["${var.repo_default_branch}"]
  }
}
EOF
}

# CloudWatch Events Target
resource "aws_cloudwatch_event_target" "pipeline" {
  target_id = "1"
  rule      = aws_cloudwatch_event_rule.pipeline_state_update.name
  arn       = aws_codepipeline.codepipeline.arn
  role_arn  = aws_iam_role.cloudwatch.arn
}

# Trust Policy for CloudWatch Events
data "aws_iam_policy_document" "cloudwatch_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# IAM Role for CloudWatch Events
resource "aws_iam_role" "cloudwatch" {
  name               = "cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_policy_document.json
}

resource "aws_iam_policy" "cloudwatch_permission_policy" {
  name        = "cloudwatch-permission-policy"
  description = "CloudWatch Permission Policy for ${var.repo_name} and CodePipeline"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "${aws_codepipeline.codepipeline.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  policy_arn = aws_iam_policy.cloudwatch_permission_policy.arn
  role       = aws_iam_role.cloudwatch.name
}

# CodePipeline Creation
resource "aws_codepipeline" "codepipeline" {
  name     = var.repo_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.artifact_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        RepositoryName       = var.repo_name
        BranchName           = var.repo_default_branch
        PollForSourceChanges = "false"
      }
    }
  }


  stage {
    name = "build"

    action {
      name     = "BuildArtifact"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = "cicd-tf-test-package"
    }
  }
}
}



###########################################
# Terraform configuration for the second module integration
###########################################
resource "aws_ecr_repository" "repo" {
  name                 = var.name
  force_delete         = var.force_delete
  image_tag_mutability = var.image_tag_mutability

  dynamic "encryption_configuration" {
    for_each = local.encryption_configuration
    content {
      encryption_type = encryption_configuration.value["encryption_type"]
      kms_key         = encryption_configuration.value["kms_key"]
    }
  }

  dynamic "image_scanning_configuration" {
    for_each = local.image_scanning_configuration
    content {
      scan_on_push = image_scanning_configuration.value["scan_on_push"]
    }
  }

  dynamic "timeouts" {
    for_each = local.timeouts
    content {
      delete = timeouts.value["delete"]
    }
  }

  tags = var.tags
}

# Policy
resource "aws_ecr_repository_policy" "policy" {
  count      = var.policy == null ? 0 : 1
  repository = aws_ecr_repository.repo.name
  policy     = var.policy
}

# Lifecycle policy
resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  count      = var.lifecycle_policy == null ? 0 : 1
  repository = aws_ecr_repository.repo.name
  policy     = var.lifecycle_policy
}

# KMS key
resource "aws_kms_key" "kms_key" {
  count       = local.should_create_kms_key ? 1 : 0
  description = "${var.name} KMS key"
}

resource "aws_kms_alias" "kms_key_alias" {
  count         = local.should_create_kms_key ? 1 : 0
  name          = "alias/${var.name}Key"
  target_key_id = aws_kms_key.kms_key[0].key_id
}

locals {
  should_create_kms_key = var.encryption_type == "KMS" && var.kms_key == null

  # If encryption type is KMS, use assigned KMS key otherwise build a new key
  encryption_configuration = local.should_create_kms_key ? [{
    encryption_type = "KMS"
    kms_key         = aws_kms_key.kms_key[0].arn
    }] : (var.encryption_type == "KMS" ? [{
      encryption_type = "KMS"
      kms_key         = var.kms_key
  }] : [])

  # Image scanning configuration
  # If no image_scanning_configuration block is provided, build one using the default values
  image_scanning_configuration = [{
    scan_on_push = var.image_scanning_configuration != null ? var.image_scanning_configuration.scan_on_push : var.scan_on_push
  }]

  # Timeouts
  # If no timeouts block is provided, build one using the default values
  timeouts = length(var.timeouts) != 0 ? [var.timeouts] : (var.timeouts_delete != null ? [{
    delete = var.timeouts_delete
  }] : [])
}



