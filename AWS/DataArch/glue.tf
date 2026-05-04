## Glue Database

resource "aws_glue_catalog_database" "gaia_catalog" {
  name = "dataarchpoc01"
}


## Glue Crawler - Exoplanets

resource "aws_glue_crawler" "exoplanets" {
  name          = "dataarchpoc01-exoplanets"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.gaia_catalog.name

  s3_target {
    path = "s3://${module.silver_bucket.s3_bucket_id}/exoplanets/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}


## Glue ETL Job - Gaia

resource "aws_s3_object" "gaia_etl_script" {
  bucket = module.silver_bucket.s3_bucket_id
  key    = "scripts/gaia_etl.py"
  source = "${path.module}/glue_scripts/gaia_etl.py"
  etag   = filemd5("${path.module}/glue_scripts/gaia_etl.py")
}

resource "aws_glue_job" "gaia_etl" {
  name         = "dataarchpoc01-gaia-etl"
  role_arn     = aws_iam_role.glue_etl.arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${module.silver_bucket.s3_bucket_id}/scripts/gaia_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--TempDir"                          = "s3://${module.silver_bucket.s3_bucket_id}/tmp/"
  }

  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 60

  depends_on = [aws_s3_object.gaia_etl_script]
}


## Glue Crawler - Gaia

resource "aws_glue_crawler" "gaia" {
  name          = "dataarchpoc01-gaia"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.gaia_catalog.name

  s3_target {
    path = "s3://${module.silver_bucket.s3_bucket_id}/gaia/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}
