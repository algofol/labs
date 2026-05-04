import boto3
import pandas as pd
from io import StringIO

BUCKET = "dataarchpoc01"
SOURCE_KEY = "raw/exoplanets.csv"
OUTPUT_PREFIX = "raw/chunks/"
CHUNK_SIZE = 1000

s3 = boto3.client("s3")

print(f"Reading s3://{BUCKET}/{SOURCE_KEY} ...")
obj = s3.get_object(Bucket=BUCKET, Key=SOURCE_KEY)
df = pd.read_csv(obj["Body"], comment="#", low_memory=False)
print(f"Total rows: {len(df)}")

for i, start in enumerate(range(0, len(df), CHUNK_SIZE)):
    chunk = df.iloc[start:start + CHUNK_SIZE]
    key = f"{OUTPUT_PREFIX}exoplanets_{i+1:04d}.csv"
    buffer = StringIO()
    chunk.to_csv(buffer, index=False)
    s3.put_object(Bucket=BUCKET, Key=key, Body=buffer.getvalue())
    print(f"Uploaded {key} ({len(chunk)} rows)")

print("Done.")
