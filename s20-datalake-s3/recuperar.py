import boto3
s3 = boto3.client("s3")
B, K = "fragilidad-datalake-ace-2026", "raw/prueba.txt"

s3.delete_object(Bucket=B, Key=K)          # borrado "lógico"
print("Borrado. ¿Existe?", "Contents" in s3.list_objects_v2(Bucket=B, Prefix=K))

v = s3.list_object_versions(Bucket=B, Prefix=K)
for d in v.get("DeleteMarkers", []):
    print("Marcador de borrado:", d["VersionId"])
    s3.delete_object(Bucket=B, Key=K, VersionId=d["VersionId"])  # quitar marcador = recuperar

print("Recuperado. ¿Existe?", "Contents" in s3.list_objects_v2(Bucket=B, Prefix=K))
print(s3.get_object(Bucket=B, Key=K)["Body"].read().decode())
