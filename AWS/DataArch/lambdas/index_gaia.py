import os
import logging
import boto3
import pandas as pd
from io import BytesIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SILVER_BUCKET = os.environ["SILVER_BUCKET"]

COLUMNS = [
    "source_id", "designation", "ref_epoch","ra", "dec", "parallax", "parallax_error", "pmra", "pmdec",
    "phot_g_mean_mag", "bp_rp", "radial_velocity", "l", "b"
]

s3 = boto3.client("s3")


def handler(event, context):
    for record in event.get("Records", []):
        src_bucket = record["s3"]["bucket"]["name"]
        src_key = record["s3"]["object"]["key"]

        logger.info(f"Processing s3://{src_bucket}/{src_key}")

        # Read CSV from bronze bucket — first 1000 rows are metadata, header is at row 1001
        obj = s3.get_object(Bucket=src_bucket, Key=src_key)
        df = pd.read_csv(obj["Body"], compression="gzip", skiprows=1000, header=0, low_memory=False)

        # Keep only the relevant columns that exist in this file
        existing = [c for c in COLUMNS if c in df.columns]
        df = df[existing]

        # Derive output key: replace prefix and change extension to .parquet
        filename = os.path.basename(src_key).replace(".csv.gz", ".parquet").replace(".csv", ".parquet")
        dest_key = f"gaia/{filename}"

        # Write Parquet to silver bucket
        buffer = BytesIO()
        df.to_parquet(buffer, engine="pyarrow", index=False)
        s3.put_object(Bucket=SILVER_BUCKET, Key=dest_key, Body=buffer.getvalue())

        logger.info(f"Written s3://{SILVER_BUCKET}/{dest_key} ({len(df)} rows)")

    # Trigger Glue crawler to update the catalog once the new data is in place
    glue = boto3.client("glue")
    try:
        glue.start_crawler(Name="dataarchpoc01-gaia")
        logger.info("Glue crawler started.")
    except glue.exceptions.CrawlerRunningException:
        logger.info("Crawler already running, skipping.")

    return {"statusCode": 200}
