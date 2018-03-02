# A simple example using S3 bucket, lambda and SNS

## RESOURCES
# Zip file with current code
data "archive_file" "init" {
  type        = "zip"
  source_file = "src/notify.py"
  output_path = "dist/notify.zip"
}

# S3 bucket
resource "aws_s3_bucket" "upload" {
  bucket = "bucket-upload-notification"
  acl    = "private"
}

# Topic definition
resource "aws_sns_topic" "upload_notification" {
  name = "upload-notifications"
}

# Lambda definition
resource "aws_lambda_function" "notify" {
  function_name    = "notify-upload"
  filename         = "dist/notify.zip"
  source_code_hash = "${data.archive_file.init.output_base64sha256}"

  role        = "${aws_iam_role.iam_role_for_notify.arn}"
  handler     = "notify.handler"
  timeout     = 10
  memory_size = 128
  runtime     = "python3.6"

  depends_on = ["data.archive_file.init"]

  environment {
    variables = {
      SNS_TOPIC = "${aws_sns_topic.upload_notification.arn}"
    }
  }
}

# Lambda alias
resource "aws_lambda_alias" "notify_live" {
  name             = "LIVE"
  description      = "Live version"
  function_name    = "${aws_lambda_function.notify.arn}"
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      "function_version", "description"
      ]
  }
}

# Notification to lambda
resource "aws_s3_bucket_notification" "new_upload" {
  bucket = "${aws_s3_bucket.upload.bucket}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_alias.notify_live.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}

## PERMISSIONS

# Role policy definition
data "aws_iam_policy_document" "notify_lamdba_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# S3 policy definition
data "aws_iam_policy_document" "notify_s3_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "${aws_s3_bucket.upload.arn}",
    ]
  }
}

# SNS policy definition
data "aws_iam_policy_document" "notify_sns_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sns:Publish",
    ]

    resources = [
      "${aws_sns_topic.upload_notification.arn}",
    ]
  }
}

# Role definition
resource "aws_iam_role" "iam_role_for_notify" {
  name               = "notify"
  assume_role_policy = "${data.aws_iam_policy_document.notify_lamdba_policy.json}"
}

# Attach policies to role
resource "aws_iam_role_policy" "notify_s3_policy" {
  role   = "${aws_iam_role.iam_role_for_notify.name}"
  policy = "${data.aws_iam_policy_document.notify_s3_policy.json}"
}

resource "aws_iam_role_policy" "notify_sns_policy" {
  role   = "${aws_iam_role.iam_role_for_notify.name}"
  policy = "${data.aws_iam_policy_document.notify_sns_policy.json}"
}

# Permission to S3 to execute lambda
resource "aws_lambda_permission" "execute_from_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.notify.arn}"
  qualifier = "${aws_lambda_alias.notify_live.name}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.upload.arn}"
}
