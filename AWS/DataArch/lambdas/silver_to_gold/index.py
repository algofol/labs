"""
Lambda: silver_to_gold
Triggered by EventBridge when either Glue crawler (exoplanets or gaia) succeeds.
Runs an Athena CTAS query to refresh the gold joined table.
"""

import os
import time
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SILVER_BUCKET    = os.environ["SILVER_BUCKET"]
GOLD_BUCKET      = os.environ["GOLD_BUCKET"]
ATHENA_WORKGROUP = os.environ.get("ATHENA_WORKGROUP", "dataarchpoc01")
DATABASE         = os.environ.get("GLUE_DATABASE", "dataarchpoc01")
GOLD_PREFIX      = "exoplanets_gaia"

CTAS_SQL = f"""
CREATE TABLE {DATABASE}.{GOLD_PREFIX}
WITH (
  format             = 'PARQUET',
  write_compression  = 'SNAPPY',
  external_location  = 's3://{GOLD_BUCKET}/{GOLD_PREFIX}/'
)
AS
SELECT DISTINCT
    e.pl_name,
    e.discoverymethod,
    e.disc_year,
    e.disc_facility,
    e.glon,
    e.glat,
    e.ra         AS exo_ra,
    e.dec        AS exo_dec,
    g.ra         AS gaia_ra,
    g.dec        AS gaia_dec,
    g.parallax,
    g.parallax_error,
    g.phot_g_mean_mag,
    g.bp_rp,
    g.radial_velocity,
    g.source_id  AS gaia_source_id
FROM {DATABASE}.exoplanets e
JOIN {DATABASE}.gaia g
  ON e.gaia_dr3_id = g.designation
WHERE e.gaia_dr3_id IS NOT NULL
  AND e.gaia_dr3_id != ''
"""

DROP_SQL = f"DROP TABLE IF EXISTS {DATABASE}.{GOLD_PREFIX}"


def handler(event, context):
    crawler = event.get("detail", {}).get("crawlerName", "unknown")
    logger.info(f"Triggered by crawler: {crawler} — checking if both tables are ready.")

    glue = boto3.client("glue")

    # Guard: only proceed if both silver tables exist in the catalog
    for table in ("exoplanets", "gaia"):
        try:
            glue.get_table(DatabaseName=DATABASE, Name=table)
        except glue.exceptions.EntityNotFoundException:
            logger.info(f"Table '{table}' not in catalog yet — skipping gold refresh until both datasets are available.")
            return

    logger.info("Both tables present — refreshing gold table.")

    athena = boto3.client("athena")

    # Drop existing gold table so CTAS can recreate it
    # (CTAS fails if the table already exists in the catalog)
    logger.info("Dropping existing gold table if present...")
    drop_resp = athena.start_query_execution(
        QueryString         = DROP_SQL,
        WorkGroup           = ATHENA_WORKGROUP,
        ResultConfiguration = {
            "OutputLocation": f"s3://{GOLD_BUCKET}/athena-results/"
        },
    )
    _wait(athena, drop_resp["QueryExecutionId"], "DROP TABLE")

    # Also clear the S3 prefix so CTAS doesn't complain about non-empty location
    s3 = boto3.client("s3")
    _delete_prefix(s3, GOLD_BUCKET, f"{GOLD_PREFIX}/")

    # Run CTAS
    logger.info("Running CTAS to rebuild gold table...")
    ctas_resp = athena.start_query_execution(
        QueryString         = CTAS_SQL,
        WorkGroup           = ATHENA_WORKGROUP,
        ResultConfiguration = {
            "OutputLocation": f"s3://{GOLD_BUCKET}/athena-results/"
        },
    )
    _wait(athena, ctas_resp["QueryExecutionId"], "CTAS")
    logger.info("Gold table refreshed successfully.")

    # Rename CTAS output files to human-readable names with .parquet extension
    _rename_parquet_files(s3, GOLD_BUCKET, f"{GOLD_PREFIX}/")


def _wait(athena, query_id, label, max_wait=300):
    """Poll until query finishes or raises on failure."""
    elapsed = 0
    while elapsed < max_wait:
        resp   = athena.get_query_execution(QueryExecutionId=query_id)
        state  = resp["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED",):
            logger.info(f"{label} query SUCCEEDED (id={query_id})")
            return
        if state in ("FAILED", "CANCELLED"):
            reason = resp["QueryExecution"]["Status"].get("StateChangeReason", "")
            raise RuntimeError(f"{label} query {state}: {reason}")
        time.sleep(5)
        elapsed += 5
    raise TimeoutError(f"{label} query timed out after {max_wait}s")


def _delete_prefix(s3, bucket, prefix):
    """Delete all objects under a prefix."""
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        objects = [{"Key": obj["Key"]} for obj in page.get("Contents", [])]
        if objects:
            s3.delete_objects(Bucket=bucket, Delete={"Objects": objects})
            logger.info(f"Deleted {len(objects)} objects from s3://{bucket}/{prefix}")


def _rename_parquet_files(s3, bucket, prefix):
    """Rename Athena CTAS output files to part-XXXXX.parquet."""
    paginator = s3.get_paginator("list_objects_v2")
    idx = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            # Skip already-renamed files and metadata (.metadata suffix)
            if key.endswith(".parquet") or key.endswith(".metadata"):
                continue
            new_key = f"{prefix}part-{idx:05d}.parquet"
            s3.copy_object(Bucket=bucket, CopySource={"Bucket": bucket, "Key": key}, Key=new_key)
            s3.delete_object(Bucket=bucket, Key=key)
            logger.info(f"Renamed s3://{bucket}/{key} → s3://{bucket}/{new_key}")
            idx += 1
