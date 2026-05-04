"""
Glue ETL job: Gaia bronze → silver
- Skips the first 1000 metadata rows
- Row 1001 (0-indexed: 1000) is the header
- Selects a subset of useful columns
- Writes Parquet to s3://<silver_bucket>/gaia/
"""

import sys
import boto3
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# ── Job arguments injected by Lambda ─────────────────────────────────────────
args = getResolvedOptions(sys.argv, ["src_bucket", "src_key", "silver_bucket"])

src_bucket   = args["src_bucket"]
src_key      = args["src_key"]
silver_bucket = args["silver_bucket"]

source_path = f"s3://{src_bucket}/{src_key}"

# ── Spark / Glue context ──────────────────────────────────────────────────────
sc    = SparkContext.getOrCreate()
spark = SparkSession(sc)

# Log4j logger via JVM gateway
log4j  = sc._jvm.org.apache.log4j
logger = log4j.LogManager.getLogger(__name__)
logger.info(f"Gaia ETL starting — source: {source_path}")

# ── Read raw lines ────────────────────────────────────────────────────────────
# The file is a gzip-compressed CSV; Spark handles .gz automatically.
raw_rdd = sc.textFile(source_path)

# Attach line number (0-based) so we can slice deterministically.
indexed = raw_rdd.zipWithIndex().cache()

# Row 1000 (0-indexed) → line 1001 → column header
header_line = (
    indexed
    .filter(lambda row: row[1] == 1000)
    .first()[0]
)
col_names = [c.strip() for c in header_line.split(",")]
logger.info(f"Detected {len(col_names)} columns from header line")

# Data rows start at index 1001 (everything after the header)
data_rdd = indexed.filter(lambda row: row[1] > 1000).map(lambda row: row[0])

# ── Parse CSV ─────────────────────────────────────────────────────────────────
# Read the data lines as a CSV (no embedded header — we'll rename manually)
df_raw = spark.read.csv(data_rdd, header=False, inferSchema=True)

# Rename _c0, _c1, … to the actual column names
rename_map = {f"_c{i}": name for i, name in enumerate(col_names)}
df_named = df_raw
for old_name, new_name in rename_map.items():
    df_named = df_named.withColumnRenamed(old_name, new_name)

# ── Column selection ──────────────────────────────────────────────────────────
KEEP_COLUMNS = [
    "source_id",
    "designation",
    "ref_epoch",
    "ra",
    "dec",
    "parallax",
    "parallax_error",
    "pmra",
    "pmdec",
    "phot_g_mean_mag",
    "bp_rp",
    "radial_velocity",
    "l",
    "b",
]

# Only keep columns that actually exist in this data release
available = [c for c in KEEP_COLUMNS if c in df_named.columns]
missing   = set(KEEP_COLUMNS) - set(available)
if missing:
    logger.warn(f"Columns not found in source and will be skipped: {missing}")

df_silver = df_named.select(available)

# ── Add provenance metadata ───────────────────────────────────────────────────
df_silver = df_silver.withColumn("_source_file", F.lit(src_key))
df_silver = df_silver.withColumn("_processed_at", F.current_timestamp())

logger.info(f"Row count after filtering: {df_silver.count()}")

# ── Write Parquet ─────────────────────────────────────────────────────────────
# All Gaia files accumulate in a single silver/gaia/ prefix.
# Using append so each new file adds to the dataset without overwriting.
output_path = f"s3://{silver_bucket}/gaia/"

logger.info(f"Writing Parquet to {output_path}")

(
    df_silver
    .write
    .mode("append")
    .parquet(output_path)
)

logger.info("Gaia ETL job completed successfully.")

# ── Trigger Glue Crawler to update the catalog ────────────────────────────────
glue_client = boto3.client("glue")
crawler_name = "dataarchpoc01-gaia"
try:
    glue_client.start_crawler(Name=crawler_name)
    logger.info(f"Glue crawler '{crawler_name}' started.")
except glue_client.exceptions.CrawlerRunningException:
    logger.info(f"Glue crawler '{crawler_name}' was already running — skipping.")
