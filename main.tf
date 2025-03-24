terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_sns_topic" "labrador_results" {
  name = "labrador-scan-results"
}

# Create role
resource "aws_iam_role" "labrador_lambda_role" {
  name = "labrador-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "scheduler.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Create IAM policy for Lambda
resource "aws_iam_role_policy" "labrador_lambda_policy" {
  name = "labrador-lambda-policy"
  role = aws_iam_role.labrador_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetBucketLocation",
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*",
          aws_sns_topic.labrador_results.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Add basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.labrador_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create Lambda function
resource "aws_lambda_function" "labrador_scanner" {
  filename         = "lambda_function.zip"
  function_name    = "labrador-s3-scanner"
  role            = aws_iam_role.labrador_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300  # 5 minutes
  memory_size     = 256
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.labrador_results.arn
    }
  }
}

# Create EventBridge Scheduler
resource "aws_scheduler_schedule" "labrador_scan_schedule" {
  name       = "labrador-scan-schedule"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "rate(5 days)"
  schedule_expression_timezone = "UTC"
  state = "ENABLED"
  target {
    arn      = aws_lambda_function.labrador_scanner.arn
    role_arn = aws_iam_role.labrador_lambda_role.arn
  }
}

# Add EventBridge Scheduler permissions to Lambda role
resource "aws_iam_role_policy" "scheduler_policy" {
  name = "labrador-scheduler-policy"
  role = aws_iam_role.labrador_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule",
          "scheduler:ListSchedules"
        ]
        Resource = "*"
      }
    ]
  })
}