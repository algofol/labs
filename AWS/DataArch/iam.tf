## IAM resources for Lambda

resource "aws_iam_role" "bronze_to_silver" {
  name = "dataarchpoc01-bronze-to-silver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.bronze_to_silver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "dataarchpoc01-lambda-s3"
  role = aws_iam_role.bronze_to_silver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          module.bronze_bucket.s3_bucket_arn,
          "${module.bronze_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${module.silver_bucket.s3_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["glue:StartCrawler", "glue:GetCrawler"]
        Resource = "arn:aws:glue:${var.aws_region}:*:crawler/dataarchpoc01-exoplanets"
      },
      {
        Effect   = "Allow"
        Action   = ["glue:StartJobRun", "glue:GetJobRun"]
        Resource = "arn:aws:glue:${var.aws_region}:*:job/dataarchpoc01-gaia-etl"
      }
    ]
  })
}


## IAM role for Glue ETL job

resource "aws_iam_role" "glue_etl" {
  name = "dataarchpoc01-glue-etl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_etl_service" {
  role       = aws_iam_role.glue_etl.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_etl_s3" {
  name = "dataarchpoc01-glue-etl-s3"
  role = aws_iam_role.glue_etl.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          module.bronze_bucket.s3_bucket_arn,
          "${module.bronze_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          module.silver_bucket.s3_bucket_arn,
          "${module.silver_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["glue:StartCrawler", "glue:GetCrawler"]
        Resource = "arn:aws:glue:${var.aws_region}:*:crawler/dataarchpoc01-gaia"
      }
    ]
  })
}


## IAM role for silver_to_gold Lambda

resource "aws_iam_role" "silver_to_gold" {
  name = "dataarchpoc01-silver-to-gold"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "silver_to_gold_logs" {
  role       = aws_iam_role.silver_to_gold.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "silver_to_gold_policy" {
  name = "dataarchpoc01-silver-to-gold-policy"
  role = aws_iam_role.silver_to_gold.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          module.silver_bucket.s3_bucket_arn,
          "${module.silver_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          module.silver_bucket.s3_bucket_arn,
          "${module.silver_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          module.gold_bucket.s3_bucket_arn,
          "${module.gold_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "arn:aws:athena:${var.aws_region}:*:workgroup/${aws_athena_workgroup.dataarchpoc01.name}"
      },
      {
        Effect   = "Allow"
        Action   = [
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetDatabase",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:DeleteTable",
          "glue:UpdateTable"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:*:catalog",
          "arn:aws:glue:${var.aws_region}:*:database/${aws_glue_catalog_database.gaia_catalog.name}",
          "arn:aws:glue:${var.aws_region}:*:table/${aws_glue_catalog_database.gaia_catalog.name}/*"
        ]
      }
    ]
  })
}


## IAM resources for Glue Crawler

resource "aws_iam_role" "glue_crawler" {
  name = "dataarchpoc01-glue-crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_read" {
  name = "dataarchpoc01-glue-s3-read"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        module.silver_bucket.s3_bucket_arn,
        "${module.silver_bucket.s3_bucket_arn}/*"
      ]
    }]
  })
}
