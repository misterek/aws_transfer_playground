resource "aws_iam_role" "sftp_shared_role" {
  name = "sftp_acces_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

locals {
  unique_buckets = distinct([for user in keys(var.sftp_users) : var.sftp_users[user].bucket_name])
}

resource "aws_iam_policy" "sftp_shared_policy" {
  name   = "sftp_shared_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket"
        ],
        "Resource": [
          for bucket in local.unique_buckets : "arn:aws:s3:::${bucket}"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": [
          for bucket in local.unique_buckets : "arn:aws:s3:::${bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sftp_shared_policy_attachment" {
  role       = aws_iam_role.sftp_shared_role.name
  policy_arn = aws_iam_policy.sftp_shared_policy.arn
}