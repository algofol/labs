import boto3
import pandas as pd
from io import StringIO, BytesIO

BUCKET = "dataarchpoc01"
SOURCE_KEY = "raw/exoplanets.csv"
OUTPUT_KEY = "raw/exoplanets_filtered.parquet"

COLUMNS = [
    "pl_name", "disc_year", "discoverymethod", "disc_facility",
    "ra", "rastr", "dec", "decstr",
    "glon", "glat", "elon", "elat",
    "x", "y", "z", "pl_pubdate"
]

s3 = boto3.client("s3")

print(f"Reading s3://{BUCKET}/{SOURCE_KEY} ...")
obj = s3.get_object(Bucket=BUCKET, Key=SOURCE_KEY)
df = pd.read_csv(obj["Body"], comment="#", low_memory=False)

print(f"Total rows: {len(df)}, Total columns: {len(df.columns)}")

df_filtered = df[COLUMNS]
print(f"Filtered to {len(df_filtered.columns)} columns")
print(df_filtered.head(3))

buffer = BytesIO()
df_filtered.to_parquet(buffer, engine="pyarrow", index=False)

print(f"Uploading to s3://{BUCKET}/{OUTPUT_KEY} ...")
s3.put_object(Bucket=BUCKET, Key=OUTPUT_KEY, Body=buffer.getvalue())
print("Done.")
