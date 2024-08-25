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
  # The roles assigned should allow it to manage the necessary infrastructure
  statement {
    sid       = "ManageS3"
    effect    = "Allow"
    actions   = ["s3:CreateBucket", "s3:PutBucketTagging", "s3:ListBucket", "s3:GetBucketTagging", "s3:GetBucketPolicy", "s3:GetBucketLogging", "s3:GetBucketAcl", "s3:GetBucketCors", "s3:GetBucketVersioning", "s3:GetBucketWebsite", "s3:GetAccelerateConfiguration", "s3:GetBucketRequestPayment", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration", "s3:GetBucketObjectLockConfiguration", "s3:PutBucketOwnershipControls", "s3:PutBucketVersioning", "s3:GetBucketOwnershipControls", "s3:PutObjectAcl", "s3:DeleteBucket", "s3:DeleteBucketPolicy", "s3:PutBucketAcl", "s3:PutBucketPolicy"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }

  # The roles assigned should allow it to use the necessary infrastructure
  statement {
    sid       = "S3UploadBuildObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }

  statement {
    sid       = "ManageCloudfront"
    effect    = "Allow"
    actions   = ["cloudfront:CreateDistribution", "cloudfront:TagResource", "cloudfront:GetDistribution", "cloudfront:ListTagsForResource", "cloudfront:DeleteDistribution", "cloudfront:UpdateDistribution", "cloudfront:CreateOriginAccessControl", "cloudfront:GetOriginAccessControl", "cloudfront:DeleteOriginAccessControl"]
    resources = ["*"]
  }

  statement {
    sid       = "ManageCloudfrontKVS"
    effect    = "Allow"
    actions   = ["cloudfront:CreateKeyValueStore", "cloudfront:DeleteKeyValueStore", "cloudfront:DescribeKeyValueStore"]
    resources = ["*"]
  }

  statement {
    sid       = "InvalidateCloudfront"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["*"]
  }

  // "arn:aws:iam::${var.aws_account_id}:role/${var.repository_name}_lambda_service_role_honeypot"
  statement {
    sid       = "ManageLambdaEdgeServiceRoleCreation"
    effect    = "Allow"
    actions   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:PassRole", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy"]
    resources = ["*"]
  }

  // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-permissions.html#using-service-linked-roles
  statement {
    sid       = "ManageLambdaEdgeServiceRoleCreationManagement"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole", "iam:DeleteServiceLinkedRole", "iam:GetServiceLinkedRoleDeletionStatus", "iam:UpdateRoleDescription", "iam:AttachRolePolicy", "iam:PutRolePolicy"]
    resources = ["arn:aws:iam::*:role/aws-service-role/replicator.lambda.amazonaws.com/"]
  }

  statement {
    sid       = "ManageLambdaEdge"
    effect    = "Allow"
    actions   = ["lambda:CreateFunction", "lambda:DeleteFunction", "lambda:TagResource", "lambda:GetFunction", "lambda:ListVersionsByFunction", "lambda:GetFunctionCodeSigningConfig", "lambda:UpdateFunctionCode", "lambda:PublishFunction", "lambda:PublishVersion", "lambda:EnableReplication*", "lambda:DisableReplication*"]
    resources = ["*"]
  }

  statement {
    sid       = "ManageCloudfrontFunction"
    effect    = "Allow"
    actions   = ["cloudfront:GetFunction", "cloudfront:CreateFunction", "cloudfront:DeleteFunction", "cloudfront:UpdateFunction", "cloudfront:PublishFunction", "cloudfront:DescribeFunction"]
    resources = ["*"]
  }

  statement {
    sid       = "ManageAWSCertManager"
    effect    = "Allow"
    actions   = ["acm:RequestCertificate", "acm:DeleteCertificate", "acm:AddTagsToCertificate", "acm:DescribeCertificate", "acm:ListTagsForCertificate"]
    resources = ["*"]
  }

  statement {
    sid       = "ManageRoute53"
    effect    = "Allow"
    actions   = ["route53:GetHostedZone", "route53:CreateHostedZone", "route53:DeleteHostedZone", "route53:GetChange", "route53:ListTagsForResource", "route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:GetDNSSEC", "route53:DeactivateKeySigningKey", "route53:DeleteKeySigningKey", "route53:EnableHostedZoneDNSSEC", "route53:DisableHostedZoneDNSSEC"]
    resources = ["*"]
  }

  statement {
    sid       = "ManageKMSForDNSSEC"
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags", "kms:ScheduleKeyDeletion", "kms:PutKeyPolicy", "route53:CreateKeySigningKey", "kms:GetPublicKey", "kms:Sign", ]
    resources = ["*"]
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