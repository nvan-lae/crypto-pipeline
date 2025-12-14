terraform {
  backend "s3" {
    bucket = "crypto-pipeline-tfstate-nvan-lae"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}

provider "aws" {
  region = "eu-west-3"
}

# --- AWS SETUP (DYNAMODB & DATASTREAM) ---

resource "aws_dynamodb_table" "crypto_table" {
  name           = "CryptoData"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

resource "aws_kinesis_stream" "crypto_stream" {
  name             = "crypto-price-stream"
  shard_count      = 1
  retention_period = 24
}

resource "aws_sns_topic" "alerts" {
  name = "crypto-price-alerts"
}

resource "aws_iam_role" "lambda_role" {
  name = "CryptoLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "CryptoLambdaPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "dynamodb:PutItem",
          "sns:Publish",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_permissions" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# --- PRODUCER LAMBDA ---

data "archive_file" "producer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/producer"
  output_path = "${path.module}/producer_payload.zip"
}

resource "aws_lambda_function" "producer_lambda" {
  filename      = data.archive_file.producer_zip.output_path
  function_name = "CryptoProducer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.producer_zip.output_base64sha256

  tracing_config {
  mode = "Active"
  }

  environment {
    variables = {
      STREAM_NAME = aws_kinesis_stream.crypto_stream.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  name        = "every-minute-trigger"
  description = "Fires every 1 minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "check_price_every_minute" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "lambda"
  arn       = aws_lambda_function.producer_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}

# --- CONSUMER LAMBDA ---

data "archive_file" "consumer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/consumer"
  output_path = "${path.module}/consumer_payload.zip"
}

resource "aws_lambda_function" "consumer_lambda" {
  filename      = data.archive_file.consumer_zip.output_path
  function_name = "CryptoConsumer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.consumer_zip.output_base64sha256

  tracing_config {
  mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME      = aws_dynamodb_table.crypto_table.name
      TOPIC_ARN       = aws_sns_topic.alerts.arn
      PRICE_THRESHOLD = "85000"
    }
  }
}

resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.crypto_stream.arn
  function_name     = aws_lambda_function.consumer_lambda.arn
  starting_position = "LATEST"
  batch_size        = 10
}

# --- DATA LAKE (S3 & FIREHOSE) ---

resource "aws_s3_bucket" "datalake" {
  bucket_prefix = "crypto-datalake-"
  force_destroy = true
}

resource "aws_iam_role" "firehose_role" {
  name = "CryptoFirehoseRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "firehose_policy" {
  name = "CryptoFirehosePolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.crypto_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.datalake.arn,
          "${aws_s3_bucket.datalake.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_firehose" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_kinesis_firehose_delivery_stream" "s3_stream" {
  name        = "crypto-to-s3-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.crypto_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.datalake.arn

    buffering_size     = 1
    buffering_interval = 60

    compression_format = "GZIP"
  }
}
