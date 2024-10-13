terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.68.0"
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

# Archive the Python script
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/auth_handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "sftp_auth_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Log Group for Lambda with 1-day retention
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/sftp_auth_lambda"
  retention_in_days = 1
}

# IAM policy for Lambda logging
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "auth_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "sftp_auth_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "auth_handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.8"

  environment {
    variables = {
      # Add any environment variables your Lambda function needs
    }
  }
}

# Lambda permission for AWS Transfer
resource "aws_lambda_permission" "allow_transfer" {
  statement_id  = "AllowTransferInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "transfer.amazonaws.com"
}

# New IAM role for AWS Transfer Server
resource "aws_iam_role" "transfer_server_role" {
  name = "sftp_transfer_server_role"

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

# IAM policy to allow invoking only the specific Lambda function
resource "aws_iam_role_policy" "invoke_lambda_policy" {
  name = "invoke_auth_lambda_policy"
  role = aws_iam_role.transfer_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = aws_lambda_function.auth_lambda.arn
      }
    ]
  })
}

# New IAM role for CloudWatch logging for Transfer server
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

# Create CloudWatch log group for Transfer server
resource "aws_cloudwatch_log_group" "transfer_log_group" {
  name              = "/aws/transfer/${var.hostname}"
  retention_in_days = 1
}

# AWS Transfer Server with Lambda authentication and CloudWatch logging
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "AWS_LAMBDA"
  function               = aws_lambda_function.auth_lambda.arn
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
  
  #invocation_role = aws_iam_role.transfer_server_role.arn
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
