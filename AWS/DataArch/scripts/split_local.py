import pandas as pd

SOURCE = "exoplanets.csv"
CHUNK_SIZE = 1000

df = pd.read_csv(SOURCE, comment="#", low_memory=False)
print(f"Total rows: {len(df)}")

for i, start in enumerate(range(0, len(df), CHUNK_SIZE)):
    chunk = df.iloc[start:start + CHUNK_SIZE]
    filename = f"exoplanets_{i+1:04d}.csv"
    chunk.to_csv(filename, index=False)
    print(f"Written {filename} ({len(chunk)} rows)")

print("Done.")
