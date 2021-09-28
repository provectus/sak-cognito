resource "aws_cloudwatch_log_group" "cognito_cloudtrail_logs" {
  count = var.enable_cloudtrail_logging ? 1 : 0
  name  = "cognito-cloudtrail-logs-${var.cluster_name}"
}

data "aws_iam_policy_document" "cloudtrail_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}


resource "random_string" "role_suffix" {
  length  = 5
  special = false
}


resource "aws_s3_bucket" "cognito_cloudtrail_logs" {

  count  = var.enable_cloudtrail_logging ? 1 : 0
  bucket = "${var.cluster_name}-cloudtrail"
  tags   = var.tags

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.cluster_name}-cloudtrail"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.cluster_name}-cloudtrail/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}



resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  count = var.enable_cloudtrail_logging ? 1 : 0
  name  = "CloudWatchWriteForCloudTrail-${random_string.role_suffix.result}"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role_policy.json
  inline_policy {
    name = "cloudwatch_write_permissions"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "cloudwatch:PutMetricData",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams",
            "logs:DescribeLogGroups",
            "logs:CreateLogStream",
            "logs:CreateLogGroup"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}


resource "aws_cloudtrail" "cognito" {
  count                         = var.enable_cloudtrail_logging ? 1 : 0
  name                          = "cognito-bucket-trail"
  s3_bucket_name                = aws_s3_bucket.cognito_cloudtrail_logs[0].id
  s3_key_prefix                 = "trail"
  include_global_service_events = false


  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cognito_cloudtrail_logs[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch[0].arn
}


resource "aws_cognito_user_pool" "this" {
  name = var.cluster_name
  admin_create_user_config {
    invite_message_template {
      email_message = var.invite_template.email_message
      email_subject = var.invite_template.email_subject
      sms_message   = var.invite_template.sms_message
    }
  }
  tags = var.tags

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

}

resource "aws_cognito_user_pool_domain" "this" {
  domain          = "auth.${var.domain}"
  certificate_arn = module.cognito_acm.this_acm_certificate_arn
  user_pool_id    = aws_cognito_user_pool.this.id
}

resource "aws_route53_record" "this" {
  name    = aws_cognito_user_pool_domain.this.domain
  type    = "A"
  zone_id = var.zone_id
  alias {
    evaluate_target_health = false
    name                   = aws_cognito_user_pool_domain.this.cloudfront_distribution_arn
    zone_id                = "Z2FDTNDATAQYW2"
  }
}

resource "aws_route53_record" "root" {
  name    = var.domain
  type    = "A"
  zone_id = var.zone_id
  ttl     = 60
  records = ["127.0.0.1"]
}

module "cognito_acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v2.0"

  domain_name          = "auth.${var.domain}"
  zone_id              = var.zone_id
  validate_certificate = true

  providers = {
    aws = aws.cognito
  }

  tags = var.tags
}

provider "aws" {
  alias  = "cognito"
  region = "us-east-1"
}
