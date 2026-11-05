import boto3
s3 = boto3.client("s3")
B = "fragilidad-datalake-ace-2026"
s3.put_bucket_lifecycle_configuration(Bucket=B, LifecycleConfiguration={"Rules": [
    {"ID": "raw-a-IA", "Filter": {"Prefix": "raw/"}, "Status": "Enabled",
     "Transitions": [{"Days": 30, "StorageClass": "STANDARD_IA"},
                     {"Days": 90, "StorageClass": "GLACIER_IR"}]},
    {"ID": "borrar-versiones-viejas", "Filter": {"Prefix": ""}, "Status": "Enabled",
     "NoncurrentVersionExpiration": {"NoncurrentDays": 30},
     "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}},
]})
for r in s3.get_bucket_lifecycle_configuration(Bucket=B)["Rules"]:
    print(r["ID"], r["Status"])
