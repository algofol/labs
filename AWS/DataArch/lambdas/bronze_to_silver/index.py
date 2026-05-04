import os
import logging
import boto3
import pandas as pd
from io import BytesIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SILVER_BUCKET = os.environ["SILVER_BUCKET"]
GLUE_JOB_NAME = os.environ.get("GLUE_JOB_NAME", "dataarchpoc01-gaia-etl")

COLUMNS = [
    "pl_name", "disc_year", "discoverymethod", "disc_facility",
    "ra", "rastr", "dec", "decstr",
    "glon", "glat", "elon", "elat",
    "x", "y", "z", "pl_pubdate",
    "gaia_dr3_id"
]

s3 = boto3.client("s3")
glue = boto3.client("glue")


def is_gaia(key: str) -> bool:
    filename = os.path.basename(key)
    return filename.startswith("GaiaSource") or key.endswith(".gz")


def process_exoplanets(src_bucket, src_key):
    obj = s3.get_object(Bucket=src_bucket, Key=src_key)
    df = pd.read_csv(obj["Body"], skiprows=126, header=0, low_memory=False)

    existing = [c for c in COLUMNS if c in df.columns]
    df = df[existing]

    filename = os.path.basename(src_key).replace(".csv", ".parquet")
    dest_key = f"exoplanets/{filename}"

    buffer = BytesIO()
    df.to_parquet(buffer, engine="pyarrow", index=False)
    s3.put_object(Bucket=SILVER_BUCKET, Key=dest_key, Body=buffer.getvalue())

    logger.info(f"Written s3://{SILVER_BUCKET}/{dest_key} ({len(df)} rows)")

    try:
        glue.start_crawler(Name="dataarchpoc01-exoplanets")
        logger.info("Exoplanets Glue crawler started.")
    except glue.exceptions.CrawlerRunningException:
        logger.info("Exoplanets crawler already running, skipping.")


def route_to_glue_etl(src_bucket, src_key):
    logger.info(f"Gaia file detected — routing s3://{src_bucket}/{src_key} to Glue ETL job.")
    glue.start_job_run(
        JobName=GLUE_JOB_NAME,
        Arguments={
            "--src_bucket": src_bucket,
            "--src_key": src_key,
            "--silver_bucket": SILVER_BUCKET,
        }
    )
    logger.info(f"Glue ETL job '{GLUE_JOB_NAME}' started.")


def handler(event, context):
    for record in event.get("Records", []):
        src_bucket = record["s3"]["bucket"]["name"]
        src_key = record["s3"]["object"]["key"]

        logger.info(f"Processing s3://{src_bucket}/{src_key}")

        if is_gaia(src_key):
            route_to_glue_etl(src_bucket, src_key)
        else:
            process_exoplanets(src_bucket, src_key)

    return {"statusCode": 200}


