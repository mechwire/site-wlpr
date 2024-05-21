terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.48.0"
    }
  }
}

provider "aws" {}

module "basic_repo_role" {
  source          = "git::https://github.com/mechwire/tf-state-remote-backend//infra/repo_role"
  aws_account_id  = var.aws_account_id
  organization    = var.organization
  repository_name = var.repository_name
}

data "aws_iam_policy_document" "repo_role" {
  # The roles assigned should allow it to create the necessary infrastructure
  statement {
    sid       = "S3CreateBucket"
    effect    = "Allow"
    actions   = ["s3:CreateBucket", "s3:PutBucketTagging", "s3:ListBucket", "s3:GetBucketTagging", "s3:GetBucketPolicy", "s3:GetBucketLogging", "s3:GetBucketAcl", "s3:GetBucketCors", "s3:GetBucketVersioning", "s3:GetBucketWebsite", "s3:GetAccelerateConfiguration", "s3:GetBucketRequestPayment", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration", "s3:GetBucketObjectLockConfiguration", "s3:PutBucketOwnershipControls", "s3:PutBucketVersioning", "s3:GetBucketOwnershipControls", "s3:PutObjectAcl", "s3:DeleteBucket", "s3:PutBucketAcl", "s3:PutBucketPolicy"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }

  # The roles assigned should allow it to modify the necessary infrastructure
  statement {
    sid       = "S3UploadBuild"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }

  statement {
    sid       = "S3UploadBuildObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }

  statement {
    sid       = "InvalidateCloudfront"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["*"] // We'll tighten this up later
  }
}

resource "aws_iam_policy" "repo_role" {
  name        = "AstroS3ToCloudfront"
  description = "Permissions to create a tagged S3 bucket, upload things to it, and serve it through Cloudfront. "
  policy      = data.aws_iam_policy_document.repo_role.json
}

resource "aws_iam_role_policy_attachment" "repo_role" {
  role       = module.basic_repo_role.name
  policy_arn = aws_iam_policy.repo_role.arn
}