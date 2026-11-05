"""Pruebas de s3util contra el bucket real (datos sintéticos, prefijo tests/)."""
import uuid
import pytest
import s3util as u

BUCKET = "fragilidad-datalake-ace-2026"


@pytest.fixture(scope="module")
def s3():
    return u.cliente()


@pytest.fixture
def clave():
    return f"tests/{uuid.uuid4().hex}.txt"


def test_subir_y_existe(s3, clave, tmp_path):
    f = tmp_path / "a.txt"
    f.write_text("dato sintetico")
    assert u.subir(s3, f, BUCKET, clave)
    assert u.existe(s3, BUCKET, clave)
    u.borrar(s3, BUCKET, clave)


def test_bajar_contenido_igual(s3, clave, tmp_path):
    f = tmp_path / "a.txt"
    f.write_text("hola")
    u.subir(s3, f, BUCKET, clave)
    destino = tmp_path / "b.txt"
    assert u.bajar(s3, BUCKET, clave, destino)
    assert destino.read_text() == "hola"
    u.borrar(s3, BUCKET, clave)


def test_no_existe(s3):
    assert u.existe(s3, BUCKET, "tests/no_existe_nunca.txt") is False


def test_bajar_inexistente_devuelve_false(s3, tmp_path):
    assert u.bajar(s3, BUCKET, "tests/no_existe_nunca.txt", tmp_path / "x") is False


def test_listar_paginado(s3, tmp_path):
    f = tmp_path / "a.txt"
    f.write_text("x")
    prefijo = f"tests/pag_{uuid.uuid4().hex}/"
    for i in range(5):
        u.subir(s3, f, BUCKET, f"{prefijo}{i}.txt")
    assert len(u.listar(s3, BUCKET, prefijo)) == 5
    for k in u.listar(s3, BUCKET, prefijo):
        u.borrar(s3, BUCKET, k)
