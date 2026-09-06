#!/usr/bin/env python3
"""Make one App Store Connect request. GET by default; writes require --allow-write.

Uses an existing team API key from environment variables. Never creates keys,
follows redirects, retries writes, or prints the private key/JWT.
"""

import argparse
import base64
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# A local, standard-library-only guard. This does not grant authority to make an Apple write.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import legal_guardrails

API_ORIGIN = "https://api.appstoreconnect.apple.com"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the bearer token to an asset host or another origin.
        return None


def validate_request(method, path, body, allow_write):
    parsed = urllib.parse.urlsplit(path)
    decoded = urllib.parse.unquote(parsed.path)
    if (
        parsed.scheme or parsed.netloc or parsed.fragment
        or not decoded.startswith(("/v1/", "/v2/"))
        or any(part in {".", ".."} for part in decoded.split("/"))
        or any(ord(char) < 33 for char in path)
        or "\\" in decoded
        or "%" in parsed.path
    ):
        raise ValueError("Use a relative /v1/ or /v2/ API path, without traversal or fragments.")
    if method not in {"GET", "POST", "PATCH"}:
        raise ValueError("Only GET, POST, and PATCH are supported; deletion is deliberately excluded.")
    if method == "GET" and body is not None:
        raise ValueError("GET must not include a body.")
    if method != "GET":
        if not allow_write:
            raise ValueError("Writes require --allow-write and prior authorization for the exact action.")
        if body is None or not isinstance(legal_guardrails.strict_json(body), dict):
            raise ValueError("Writes require a JSON object in --body.")
        payload = legal_guardrails.strict_json(body)
        data = payload.get("data")
        attributes = data.get("attributes") if isinstance(data, dict) else None
        if isinstance(attributes, dict) and "releaseType" in attributes and attributes["releaseType"] != "MANUAL":
            raise ValueError("This remediation release requires manual release control; automatic release is blocked.")


def encode(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=")


def make_token(key_id, issuer_id, private_key_bytes, now):
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

    key = serialization.load_pem_private_key(private_key_bytes, password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey) or not isinstance(key.curve, ec.SECP256R1):
        raise ValueError("The team API key must be an ES256/P-256 private key.")
    header = encode(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    claims = encode(json.dumps({
        "iss": issuer_id, "iat": now, "exp": now + 300, "aud": "appstoreconnect-v1"
    }).encode())
    message = header + b"." + claims
    r, s = decode_dss_signature(key.sign(message, ec.ECDSA(hashes.SHA256())))
    signature = encode(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    return (message + b"." + signature).decode()


def request(method, path, body, token):
    req = urllib.request.Request(
        API_ORIGIN + path, data=body, method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
    )
    opener = urllib.request.build_opener(NoRedirect())
    with opener.open(req, timeout=45) as response:
        result = response.read()
        return json.loads(result) if result else {"status": response.status}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Relative Apple API path; quote query strings")
    parser.add_argument("--method", default="GET", choices=["GET", "POST", "PATCH"])
    parser.add_argument("--body", type=Path, help="Reviewed JSON payload file, kept outside git")
    parser.add_argument("--allow-write", action="store_true", help="Enable this explicit write; not a grant of authority")
    parser.add_argument("--release-evidence", type=Path,
                        help="Private source/build-bound approvals for this exact request; never commit them")
    args = parser.parse_args(argv)
    try:
        body = args.body.read_bytes() if args.body else None
        validate_request(args.method, args.path, body, args.allow_write)
        stage = legal_guardrails.request_stage(args.method, args.path, body)
        if stage is not None:
            if args.release_evidence is None:
                raise ValueError("This write requires --release-evidence; --allow-write alone cannot submit or publish.")
            evidence = legal_guardrails.validate_release_file(
                args.release_evidence, Path(__file__).resolve().parents[1], stage)
            if not legal_guardrails.request_matches(
                evidence.get("authorized_request"), args.method, args.path, body):
                raise ValueError("Owner approval does not match this exact method, path and payload.")
        names = ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_PATH")
        missing = [name for name in names if not os.environ.get(name)]
        if missing:
            raise ValueError("Missing environment variables: " + ", ".join(missing))
        token = make_token(
            os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"],
            Path(os.environ["ASC_PRIVATE_KEY_PATH"]).expanduser().read_bytes(), int(time.time()),
        )
        print(json.dumps(request(args.method, args.path, body, token), indent=2))
        return 0
    except urllib.error.HTTPError as error:
        print(f"Apple returned HTTP {error.code}; no automatic retry.", file=sys.stderr)
        print(error.read().decode("utf-8", errors="replace"), file=sys.stderr)
    except (OSError, ValueError, ImportError) as error:
        print(f"API request failed: {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
