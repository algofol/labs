# Building a Serverless Data Architecture on AWS: From Raw Astronomy Data to a Gold Joined Dataset

I wanted to build a real-world data architecture PoC on AWS. Not by using fake data, but with
something more real, that's why I picked two publicly available astronomy datasets: the NASA
Exoplanet Archive (a catalogue of every confirmed exoplanet we know of, with 39000+ records) and the Gaia DR3 catalogue
(the European Space Agency's billion-star survey). The goal: ingest raw files, clean and transform
them through a medallion architecture, join them in a gold layer, and expose the result through
Amazon Athena.

# Architecture


![DataArchitecture](https://raw.githubusercontent.com/algofol/labs/main/AWS/DataArch/DataArchitecture.png)

There are two different file formats to be handled here: NASA's dataset file comes in a CSV file format, and ESA's datasets have CSV.GZ file format instead.
Once uploaded "bronze-to-silver" lambda is triggered: 
- If dataset comes from NASA Exoplanets(.csv), it will convert the file straightaway into Parquet format and triggers the Glue crwaler to extract metadata from that dataset. 
- If dataset comes from ESA Gaia(csv.gz), then it will trigger a Glue ETL job to handle efficiently nearly 500k rows(with Lambda that would be ended with an OOM error), and outputs a snappy.parquet into the silver bucket
When the Glue Crawler succeeds, EventBridge triggers the Silver-to-Gold function, that calls Athena to **join** both Parquet files by the **ESA field called "designation" and the NASA field "gaia_dr3_id"**. 

When both fields have the same value, it means that for the **same planet** there will be columns that complement information **from both datasets**, resulting a parquet file with all matches that is ready to be used by BI tools, although, for example, maybe a transform into CSV is be needed by QuickSight.

# Affordable for everyone
Full deployment of resources plus the usage of the lab wouldn't be more than **few bucks** at most, although terraform will deploy and configure **Athena, Glue, Lambda, S3, IAM and CloudWatch** resources for you.

# How to use this lab
First step is to clone this repo:
```
git clone https://github.com/algofol/labs.git
```
Code is Terraform-ready so you only need to run 
```
cd labs/AWS/DataArch
terraform init
terraform apply
.
.
.
Apply complete! Resources: 34 added, 0 changed, 0 destroyed.
```
and it will create all the necessary resources on the eu-north-1 region. If you want to change that, please edit the aws_region variable in variables.tf file

- Check the S3 buckets, they have a random suffix to avoid reusing unique names:
```
$ aws s3 ls
2026-05-04 13:06:46 dataarchpoc01bronze-d12979ce
2026-05-04 13:06:24 dataarchpoc01silver-d12979ce
2026-05-04 13:06:24 dataarchpoc01gold-d12979ce
```

- Upload directly one of the ESA's datasets into the bronze bucket and check logs from Bronze-to-Silver lambda function(timestamps removed for better reading):
```
curl -sL "https://cdn.gea.esac.esa.int/Gaia/gdr3/gaia_source/GaiaSource_000000-003111.csv.gz"   | aws s3 cp - s3://dataarchpoc01bronze-d12979ce/gaia/GaiaSource_000000-003111.csv.gz
aws logs tail /aws/lambda/dataarchpoc01-bronze-to-silver --region 
eu-north-1 --since 12h --follow
.
.
.
START RequestId: f9ca043f-d3e7-480a-bce8-2801e6ac7412 Version: $LATEST
Processing s3://dataarchpoc01bronze-d12979ce/gaia/GaiaSource_000000-003111.csv.gz
Gaia file detected — routing s3://dataarchpoc01bronze-d12979ce/gaia/GaiaSource_000000-003111.csv.gz to Glue ETL job.
Glue ETL job 'dataarchpoc01-gaia-etl' started.
END RequestId: f9ca043f-d3e7-480a-bce8-2801e6ac7412
Duration: 184.57 ms     Billed Duration: 2924 ms        Memory Size: 2048 MB    Max Memory Used: 200 MB   Init Duration: 2739.20 ms
```

Once the Gaia Glue ETL job and Crawler finishes(that could take up to 3 minutes), it will trigger the silver-to-gold lambda function, but since there's no data from the other dataset yet, it just simply quits:
```
aws logs tail /aws/lambda/dataarchpoc01-silver-to-gold --region eu-north-1 --since 12h --follow
.
.
.
START RequestId: d1528aa8-147f-427e-82c6-2e652c6148ce Version: $LATEST
Triggered by crawler: dataarchpoc01-gaia — checking if both tables are ready.
Table 'exoplanets' not in catalog yet — skipping gold refresh until both datasets are available.
END RequestId: d1528aa8-147f-427e-82c6-2e652c6148ce
Duration: 1292.87 ms    Billed Duration: 1598 ms        Memory Size: 256 MB     Max Memory Used: 92 MB    Init Duration: 304.55 ms
```

- Download Exoplanets dataset:
https://exoplanetarchive.ipac.caltech.edu/cgi-bin/TblView/nph-tblView?app=ExoTbls&config=PS
Click on Download Table(CSV format,Download all columns,Download all rows,check the Values Only checkbox,Download Table)
![Exoplanet_dataset](https://github.com/algofol/labs/blob/main/AWS/DataArch/Exoplanet_dataset.png?raw=true)

- Upload it to the bronze bucket and check the lambda logs to see that is triggered: 
```
aws s3 cp /home/<Your_User>/Downloads/PS_2026.04.30_01.55.49.csv s3://dataarchpoc01bronze-d12979ce/
aws logs tail /aws/lambda/dataarchpoc01-bronze-to-silver --region eu-north-1 --since 12h --follow
.
.
.
START RequestId: bf8bcb2a-54d5-4d8f-9fe8-30cbba416fd2 Version: $LATEST
Processing s3://dataarchpoc01bronze-d12979ce/PS_2026.04.30_01.55.49.csv
Written s3://dataarchpoc01silver-d12979ce/exoplanets/PS_2026.04.30_01.55.49.parquet (39803 rows)
Exoplanets Glue crawler started.
END RequestId: bf8bcb2a-54d5-4d8f-9fe8-30cbba416fd2
Duration: 2067.83 ms    Billed Duration: 2068 ms        Memory Size: 2048 MB    Max Memory Used: 362 MB
```

- Check logs on the Silver-to-Gold lambda function, now it should run Athena to join both tables:
```
START RequestId: b470dd2d-ff65-4f26-a908-cf5391a94527 Version: $LATEST
Triggered by crawler: dataarchpoc01-exoplanets — checking if both tables are ready.
Both tables present — refreshing gold table.
Dropping existing gold table if present...
DROP TABLE query SUCCEEDED (id=b88669ce-f408-4f91-9e73-22ba66a24e50)
Running CTAS to rebuild gold table...
CTAS query SUCCEEDED (id=e8d9c8ec-0bd3-4f38-9aba-33d7964220f7)
Gold table refreshed successfully.
Renamed s3://dataarchpoc01gold-d12979ce/exoplanets_gaia/20260504_111434_00079_ntubv_0461d84e-479c-4cf9-b325-4728e333ea9f → s3://dataarchpoc01gold-d12979ce/exoplanets_gaia/part-00000.parquet
END RequestId: b470dd2d-ff65-4f26-a908-cf5391a94527
Duration: 11603.05 ms   Billed Duration: 11604 ms       Memory Size: 256 MB     Max Memory Used: 104 MB
```

And at last you can download that file from the gold bucket and check its contents in Parquet format locally with duckdb:
```
aws s3api get-object --bucket dataarchpoc01gold-d12979ce --key exo
planets_gaia/part-00000.parquet part-00000.parquet
duckdb -c "INSTALL httpfs; LOAD httpfs; SELECT * FROM read_parquet
('part-00000.parquet');"
.
.
.
┌────────────┬─────────────────┬───────────┬───────────────────────┬───┬───────────┬─────────────────┬───────────────────┐
│  pl_name   │ discoverymethod │ disc_year │     disc_facility     │ … │   bp_rp   │ radial_velocity │  gaia_source_id   │
│  varchar   │     varchar     │  double   │        varchar        │ … │  varchar  │     varchar     │       int64       │
├────────────┼─────────────────┼───────────┼───────────────────────┼───┼───────────┼─────────────────┼───────────────────┤
│ HD 14787 b │ Radial Velocity │    2018.0 │ W. M. Keck Observato… │ … │ 1.09621   │ -8.270898       │ 24570756281835392 │
│ TOI-2537 c │ Radial Velocity │    2024.0 │ Multiple Observatori… │ … │ 1.3522882 │ 61.274906       │ 12320268307415552 │
│ TOI-2431 b │ Transit         │    2026.0 │ Transiting Exoplanet… │ … │ 1.6618462 │ 12.123357       │ 22707874346819712 │
│ TOI-2537 b │ Transit         │    2024.0 │ Transiting Exoplanet… │ … │ 1.3522882 │ 61.274906       │ 12320268307415552 │
│ TOI-4640 b │ Transit         │    2026.0 │ Transiting Exoplanet… │ … │ 0.8437977 │ 11.364447       │ 23544671414999680 │
│ TOI-5532 b │ Transit         │    2026.0 │ Transiting Exoplanet… │ … │ 1.78584   │ 8.675014        │  5900705244680192 │
│ CD Cet b   │ Radial Velocity │    2020.0 │ Calar Alto Observato… │ … │ 3.3437214 │ 28.16455        │  3179036008830848 │
└────────────┴─────────────────┴───────────┴───────────────────────┴───┴───────────┴─────────────────┴───────────────────┘
  7 rows                              use .last to show entire result                               16 columns (7 shown)

```

There you go! There are 7 planets from NASA Exoplanets dataset that matches records from ESA Gaia DR3, enriching the information that come from 2 different sources.