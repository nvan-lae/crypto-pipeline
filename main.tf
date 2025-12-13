provider "aws" {
  region = "eu-west-3"
}

# --- AWS SETUP ---

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
          "logs:PutLogEvents"
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
