# Bucket policy: Admins access bucket directly, everyone else must use access points
# Denies direct bucket access unless you're an admin or using an access point from this account
data "aws_iam_policy_document" "secure_bucket_policy" {
  statement {
    sid     = "DenyDirectAccessExceptAdminsAndAccessPoints"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.secure_bucket.arn,
      "${aws_s3_bucket.secure_bucket.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    # Deny if NOT admin
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.admin_role_arns
    }
    # AND not from access point
    condition {
      test     = "StringNotEquals"
      variable = "s3:DataAccessPointAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "secure_bucket_policy" {
  bucket = aws_s3_bucket.secure_bucket.id
  policy = data.aws_iam_policy_document.secure_bucket_policy.json
}

