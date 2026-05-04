data "archive_file" "bronze_to_silver" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/bronze_to_silver"
  output_path = "${path.module}/lambdas/bronze_to_silver.zip"
}

locals {
  pandas_layer_arn = "arn:aws:lambda:eu-north-1:336392948345:layer:AWSSDKPandas-Python313:9"
}

resource "aws_lambda_function" "bronze_to_silver" {
  function_name    = "dataarchpoc01-bronze-to-silver"
  role             = aws_iam_role.bronze_to_silver.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 900
  memory_size      = 2048
  filename         = data.archive_file.bronze_to_silver.output_path
  source_code_hash = data.archive_file.bronze_to_silver.output_base64sha256
  layers = [local.pandas_layer_arn]
  ephemeral_storage {
    size = 2048
  }
  environment {
    variables = {
      SILVER_BUCKET  = module.silver_bucket.s3_bucket_id
      GLUE_JOB_NAME  = aws_glue_job.gaia_etl.name
    }
  }
}

resource "aws_cloudwatch_log_group" "bronze_to_silver" {
  name              = "/aws/lambda/${aws_lambda_function.bronze_to_silver.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_bronze_bucket" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bronze_to_silver.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.bronze_bucket.s3_bucket_arn
}

resource "aws_s3_bucket_notification" "bronze_trigger" {
  bucket     = module.bronze_bucket.s3_bucket_id
  depends_on = [aws_lambda_permission.allow_bronze_bucket]

  lambda_function {
    lambda_function_arn = aws_lambda_function.bronze_to_silver.arn
    events              = ["s3:ObjectCreated:*"]
  }
}


## Silver → Gold Lambda

data "archive_file" "silver_to_gold" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/silver_to_gold"
  output_path = "${path.module}/lambdas/silver_to_gold.zip"
}

resource "aws_lambda_function" "silver_to_gold" {
  function_name    = "dataarchpoc01-silver-to-gold"
  role             = aws_iam_role.silver_to_gold.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.silver_to_gold.output_path
  source_code_hash = data.archive_file.silver_to_gold.output_base64sha256

  environment {
    variables = {
      SILVER_BUCKET    = module.silver_bucket.s3_bucket_id
      GOLD_BUCKET      = module.gold_bucket.s3_bucket_id
      ATHENA_WORKGROUP = aws_athena_workgroup.dataarchpoc01.name
      GLUE_DATABASE    = aws_glue_catalog_database.gaia_catalog.name
    }
  }
}

resource "aws_cloudwatch_log_group" "silver_to_gold" {
  name              = "/aws/lambda/${aws_lambda_function.silver_to_gold.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_eventbridge_silver_to_gold" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.silver_to_gold.function_name
  principal     = "events.amazonaws.com"
}

