## EventBridge rules — trigger silver_to_gold when either crawler succeeds

resource "aws_cloudwatch_event_rule" "crawler_succeeded" {
  name        = "dataarchpoc01-crawler-succeeded"
  description = "Fires when either Glue crawler finishes successfully"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Crawler State Change"]
    detail = {
      crawlerName = [
        aws_glue_crawler.exoplanets.name,
        aws_glue_crawler.gaia.name
      ]
      state = ["Succeeded"]
    }
  })
}

resource "aws_cloudwatch_event_target" "silver_to_gold" {
  rule      = aws_cloudwatch_event_rule.crawler_succeeded.name
  target_id = "silver-to-gold-lambda"
  arn       = aws_lambda_function.silver_to_gold.arn
}
