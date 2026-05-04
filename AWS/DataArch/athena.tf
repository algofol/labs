## Athena Workgroup

resource "aws_athena_workgroup" "dataarchpoc01" {
  name          = "dataarchpoc01"
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${module.gold_bucket.s3_bucket_id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    enforce_workgroup_configuration    = false
    publish_cloudwatch_metrics_enabled = true
  }
}
