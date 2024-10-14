terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.68.0" # Versions after this currently have issues with M1 Macs
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
}

terraform {
  backend "s3" {
    region = "us-east-2"
    bucket = "brad-tf-bucket"
    key    = "aws_transfer_playground_test"
  }
}

# Create IAM role for CloudWatch logging
resource "aws_iam_role" "transfer_cloudwatch_role" {
  name = "transfer_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatch logging policy to the role
resource "aws_iam_role_policy_attachment" "transfer_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
  role       = aws_iam_role.transfer_cloudwatch_role.name
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "transfer_log_group" {
  name              = "/aws/transfer/${var.hostname}"
  retention_in_days = 1
}

# AWS Transfer can use a vpc endpoint or public endpoints. Simplicity for now, we will use public.
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  protocols              = ["SFTP"]
  domain                 = "S3"
  
  logging_role = aws_iam_role.transfer_cloudwatch_role.arn
  
  structured_log_destinations = [
    "${aws_cloudwatch_log_group.transfer_log_group.arn}:*"
  ]

  tags = {
    Environment = "playground"
    Name        = var.hostname
  }
}

resource "aws_transfer_tag" "hostname" {
  resource_arn = aws_transfer_server.sftp_server.arn
  key          = "aws:transfer:customHostname"
  value        = var.hostname
}

# Data source for the Route 53 hosted zone
data "aws_route53_zone" "r53_zone" {
  name         = var.route53_zone_name
  private_zone = false
}

# Create a CNAME record for the SFTP server
resource "aws_route53_record" "sftp_cname" {
  zone_id = data.aws_route53_zone.r53_zone.zone_id
  name    = var.hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_transfer_server.sftp_server.endpoint]
}

resource "aws_transfer_user" "sftp_user" {
  for_each = var.sftp_users

  server_id      = aws_transfer_server.sftp_server.id 
  user_name      = each.key
  role           = aws_iam_role.sftp_shared_role.arn
  #home_directory = each.value.home_directory

  # A couple of ways to restrict this. Could add a policy to the user (to restrict from the main role),
  # Or can restrict the home directory.  This will drop the user into the apparent "/", directory, which
  # is actually mapped to "/home/username" in the bucket.  This should restrict users from seeing other
  # user's files.
  # Ignoring the named home directory in the variable.
  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${each.value.bucket_name}/home/$${Transfer:UserName}"
  }

  tags = {
    Name = each.key
  }
}

# Seems like the key doesn't work that well if you do it too quickly.
resource "time_sleep" "wait_for_user_creation" {
  depends_on = [aws_transfer_user.sftp_user]
  create_duration = "15s"
}

resource "aws_transfer_ssh_key" "user_ssh_key" {
  for_each   = var.sftp_users
  server_id  = aws_transfer_server.sftp_server.id
  user_name  = each.key
  body       = each.value.ssh_key

  depends_on = [time_sleep.wait_for_user_creation]
}
