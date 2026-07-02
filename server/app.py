import json
import os
import sqlite3
import threading
import time
from datetime import datetime, timezone
from functools import wraps

import jwt
import requests
from cryptography import x509
from flask import Flask, g, jsonify, request


DATABASE_PATH = os.environ.get("DATABASE_PATH", "/data/jp_driver.sqlite3")
FIREBASE_PROJECT_ID = os.environ["FIREBASE_PROJECT_ID"]
ALLOWED_ORIGINS = {
    "https://remoooo.com",
    "http://localhost",
    "http://127.0.0.1",
}
FIREBASE_CERT_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)

_certificate_cache = {}
_certificate_cache_expires_at = 0
_certificate_lock = threading.Lock()

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024


def database():
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS user_progress (
            uid TEXT PRIMARY KEY,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    return connection


def origin_is_allowed(origin):
    if not origin:
        return False
    if origin in ALLOWED_ORIGINS:
        return True
    return origin.startswith("http://localhost:") or origin.startswith(
        "http://127.0.0.1:"
    )


def firebase_certificates():
    global _certificate_cache, _certificate_cache_expires_at
    now = time.time()
    if _certificate_cache and now < _certificate_cache_expires_at:
        return _certificate_cache
    with _certificate_lock:
        now = time.time()
        if _certificate_cache and now < _certificate_cache_expires_at:
            return _certificate_cache
        response = requests.get(FIREBASE_CERT_URL, timeout=5)
        response.raise_for_status()
        certificates = response.json()
        if not isinstance(certificates, dict) or not certificates:
            raise ValueError("Firebase certificates are unavailable")
        max_age = 300
        for directive in response.headers.get("Cache-Control", "").split(","):
            name, separator, value = directive.strip().partition("=")
            if separator and name.lower() == "max-age" and value.isdigit():
                max_age = int(value)
                break
        _certificate_cache = certificates
        _certificate_cache_expires_at = now + max_age
        return _certificate_cache


def verify_firebase_id_token(token):
    header = jwt.get_unverified_header(token)
    if header.get("alg") != "RS256" or not header.get("kid"):
        raise ValueError("Invalid Firebase token header")
    certificate = firebase_certificates().get(header["kid"])
    if certificate is None:
        raise ValueError("Unknown Firebase certificate")
    public_key = x509.load_pem_x509_certificate(certificate.encode("utf-8")).public_key()
    decoded = jwt.decode(
        token,
        public_key,
        algorithms=["RS256"],
        audience=FIREBASE_PROJECT_ID,
        issuer="https://securetoken.google.com/" + FIREBASE_PROJECT_ID,
        options={"require": ["exp", "iat", "sub", "auth_time"]},
    )
    uid = decoded.get("sub")
    if not isinstance(uid, str) or not uid or len(uid) > 128:
        raise ValueError("Invalid Firebase uid")
    if decoded.get("auth_time", 0) > time.time():
        raise ValueError("Invalid Firebase auth time")
    return uid


@app.after_request
def add_cors_headers(response):
    origin = request.headers.get("Origin")
    if origin_is_allowed(origin):
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Vary"] = "Origin"
        response.headers["Access-Control-Allow-Headers"] = (
            "Authorization, Content-Type"
        )
        response.headers["Access-Control-Allow-Methods"] = "GET, PUT, OPTIONS"
    response.headers["Cache-Control"] = "no-store"
    return response


def authenticated(handler):
    @wraps(handler)
    def wrapped(*args, **kwargs):
        if request.method == "OPTIONS":
            return ("", 204)
        authorization = request.headers.get("Authorization", "")
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            return jsonify(error="unauthorized", message="認証が必要です。"), 401
        try:
            uid = verify_firebase_id_token(token)
        except Exception as error:
            app.logger.warning(
                "Firebase token rejected: %s: %s",
                type(error).__name__,
                error,
            )
            return jsonify(error="invalid_token", message="認証情報が無効です。"), 401
        g.uid = uid
        return handler(*args, **kwargs)

    return wrapped


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.route("/v1/me", methods=["GET", "OPTIONS"])
@authenticated
def me():
    return jsonify(uid=g.uid)


@app.route("/v1/progress", methods=["GET", "PUT", "OPTIONS"])
@authenticated
def progress():
    if request.method == "GET":
        with database() as connection:
            row = connection.execute(
                "SELECT data_json, updated_at FROM user_progress WHERE uid = ?",
                (g.uid,),
            ).fetchone()
        if row is None:
            return jsonify(error="not_found", message="保存データがありません。"), 404
        return jsonify(data=json.loads(row["data_json"]), updatedAt=row["updated_at"])

    payload = request.get_json(silent=True)
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        return jsonify(error="invalid_data", message="保存データが正しくありません。"), 400
    encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    updated_at = datetime.now(timezone.utc).isoformat()
    with database() as connection:
        connection.execute(
            """
            INSERT INTO user_progress (uid, data_json, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(uid) DO UPDATE SET
                data_json = excluded.data_json,
                updated_at = excluded.updated_at
            """,
            (g.uid, encoded, updated_at),
        )
    return jsonify(uid=g.uid, updatedAt=updated_at)


@app.errorhandler(413)
def payload_too_large(_error):
    return jsonify(error="payload_too_large", message="保存データが大きすぎます。"), 413
