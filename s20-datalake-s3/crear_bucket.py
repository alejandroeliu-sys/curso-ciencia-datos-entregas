"""Crea el bucket del data lake: privado, cifrado (SSE-S3), con versionado y zonas raw/staging/curated."""
import boto3
from botocore.exceptions import ClientError

BUCKET = "fragilidad-datalake-ace-2026"
REGION = "us-east-2"
s3 = boto3.Session(profile_name="tesis").client("s3", region_name=REGION)

try:
    s3.create_bucket(Bucket=BUCKET,
                     CreateBucketConfiguration={"LocationConstraint": REGION})
    print("Bucket creado")
except ClientError as e:
    if e.response["Error"]["Code"] == "BucketAlreadyOwnedByYou":
        print("El bucket ya existe y es tuyo")
    else:
        raise

# Bloquear todo acceso público
s3.put_public_access_block(Bucket=BUCKET, PublicAccessBlockConfiguration={
    "BlockPublicAcls": True, "IgnorePublicAcls": True,
    "BlockPublicPolicy": True, "RestrictPublicBuckets": True})

# Cifrado por defecto
s3.put_bucket_encryption(Bucket=BUCKET, ServerSideEncryptionConfiguration={
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]})

# Versionado
s3.put_bucket_versioning(Bucket=BUCKET, VersioningConfiguration={"Status": "Enabled"})

# Zonas (prefijos vacíos)
for zona in ["raw/", "staging/", "curated/"]:
    s3.put_object(Bucket=BUCKET, Key=zona)

# Verificación
print("Versionado:", s3.get_bucket_versioning(Bucket=BUCKET).get("Status"))
print("Cifrado:", s3.get_bucket_encryption(Bucket=BUCKET)["ServerSideEncryptionConfiguration"]["Rules"][0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"])
print("Bloqueo público:", all(s3.get_public_access_block(Bucket=BUCKET)["PublicAccessBlockConfiguration"].values()))
print("Zonas:", [o["Key"] for o in s3.list_objects_v2(Bucket=BUCKET).get("Contents", [])])
