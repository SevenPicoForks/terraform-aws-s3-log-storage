# ------------------------------------------------------------------------------
# S3 Log Storage Context
# ------------------------------------------------------------------------------
module "s3_log_storage_context" {
  source     = "SevenPico/context/null"
  version    = "2.0.0"
  context    = module.context.self
  attributes = ["cloudtrail-logs"]
}


# ------------------------------------------------------------------------------
# S3 Log Storage Policy
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_log_storage" {
  count = module.s3_log_storage_context.enabled ? 1 : 0
  #  source_policy_documents = var.s3_bucket_policy_source_json == "" ? [] : [var.s3_bucket_policy_source_json]

  statement {
    sid = "AWSCloudTrailAclCheck"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
    ]
    resources = [
      "${local.arn_prefix}:s3:::${module.s3_log_storage_context.id}",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = concat([local.account_id], var.source_accounts)
    }
    #    condition {
    #      test     = "ArnLike"
    #      variable = "aws:SourceArn"
    #      values   = concat(
    #        ["${local.arn_prefix}:logs:*:${local.account_id}:*"],
    #        [for account in var.source_accounts : "arn:aws:logs:*:${account}:*"]
    #      )
    #    }
  }
  statement {
    sid = "AWSCloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject"
    ]
    resources = [
      "${local.arn_prefix}:s3:::${module.s3_log_storage_context.id}/*",
    ]
    #    condition {
    #      test     = "StringEquals"
    #      variable = "s3:x-amz-acl"
    #
    #      values = [
    #        "bucket-owner-full-control",
    #      ]
    #    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = concat([local.account_id], var.source_accounts)
    }
    #    condition {
    #      test     = "ArnLike"
    #      variable = "aws:SourceArn"
    #      values   = concat(
    #        ["${local.arn_prefix}:logs:*:${local.account_id}:*"],
    #        [for account in var.source_accounts : "arn:aws:logs:*:${account}:*"]
    #      )
    #    }
  }
}

# ------------------------------------------------------------------------------
# S3 Bucket
# ------------------------------------------------------------------------------
module "s3_log_storage" {
  source  = "../../"
  context = module.s3_log_storage_context.self

  access_log_bucket_name            = var.access_log_bucket_name
  access_log_bucket_prefix_override = var.access_log_bucket_prefix_override
  acl                               = "log-delivery-write"
  allow_encrypted_uploads_only      = false
  allow_ssl_requests_only           = true
  block_public_acls                 = true
  block_public_policy               = true
  bucket_key_enabled                = false
  bucket_name                       = ""
  bucket_notifications_enabled      = false
  bucket_notifications_prefix       = ""
  bucket_notifications_type         = "SQS"
  enable_mfa_delete                 = var.enable_mfa_delete
  force_destroy                     = var.force_destroy
  ignore_public_acls                = true
  kms_master_key_arn                = module.kms_key.alias_arn
  lifecycle_configuration_rules     = var.lifecycle_configuration_rules
  restrict_public_buckets           = true
  s3_object_ownership               = var.s3_object_ownership
  source_policy_documents           = concat([one(data.aws_iam_policy_document.s3_log_storage[*].json)], var.s3_source_policy_documents)
  sse_algorithm                     = module.kms_key.alias_arn == "" ? "AES256" : "aws:kms"
  enable_versioning                 = true
}
