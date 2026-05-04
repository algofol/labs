# Random suffix to ensure globally unique S3 bucket names.
# Generated once and stored in state — does not change on subsequent applies.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_bronze = "dataarchpoc01bronze-${random_id.suffix.hex}"
  bucket_silver = "dataarchpoc01silver-${random_id.suffix.hex}"
  bucket_gold   = "dataarchpoc01gold-${random_id.suffix.hex}"
}

module "bronze_bucket" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "5.12.0"
  bucket        = local.bucket_bronze
  force_destroy = true
}

module "silver_bucket" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "5.12.0"
  bucket        = local.bucket_silver
  force_destroy = true
}

module "gold_bucket" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "5.12.0"
  bucket        = local.bucket_gold
  force_destroy = true
}
