"""Utilidades S3 para el data lake: subir, bajar, listar (paginado) y borrar, con manejo de ClientError."""
import logging
import boto3
from botocore.exceptions import ClientError

log = logging.getLogger(__name__)


def cliente(perfil="tesis", region="us-east-2"):
    return boto3.Session(profile_name=perfil).client("s3", region_name=region)


def subir(s3, archivo, bucket, clave):
    try:
        s3.upload_file(str(archivo), bucket, clave)
        return True
    except ClientError as e:
        log.error("No se pudo subir %s: %s", clave, e.response["Error"]["Code"])
        return False


def bajar(s3, bucket, clave, destino):
    try:
        s3.download_file(bucket, clave, str(destino))
        return True
    except ClientError as e:
        log.error("No se pudo bajar %s: %s", clave, e.response["Error"]["Code"])
        return False


def listar(s3, bucket, prefijo=""):
    """Devuelve TODAS las claves bajo un prefijo (más de 1000 vía paginador)."""
    claves = []
    for pagina in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefijo):
        claves += [o["Key"] for o in pagina.get("Contents", [])]
    return claves


def existe(s3, bucket, clave):
    try:
        s3.head_object(Bucket=bucket, Key=clave)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def borrar(s3, bucket, clave):
    try:
        s3.delete_object(Bucket=bucket, Key=clave)
        return True
    except ClientError as e:
        log.error("No se pudo borrar %s: %s", clave, e.response["Error"]["Code"])
        return False
