"""Offline checks only: synthetic keys and mocked HTTP; no Apple account changes."""

import base64
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

spec = importlib.util.spec_from_file_location("asc_api", Path(__file__).parents[1] / "asc-api.py")
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class APIClientTests(unittest.TestCase):
    def test_relative_query_is_allowed(self):
        api.validate_request("GET", "/v1/builds?filter[app]=123&limit=5", None, False)

    def test_unsafe_paths_rejected(self):
        for path in (
            "https://example.com/v1/apps", "//example.com/v1/apps", "/other/apps",
            "/v1/../apps", "/v1/%2e%2e/apps", "/v1/apps#fragment", "/v1/apps\n",
            "/v1/\\example.com/apps",
        ):
            with self.subTest(path=path), self.assertRaises(ValueError):
                api.validate_request("GET", path, None, False)

    def test_write_and_body_guards(self):
        for method, body, allowed in (
            ("PATCH", b"{}", False), ("POST", None, True), ("POST", b"[]", True),
            ("POST", b"not-json", True), ("GET", b"{}", False), ("DELETE", None, True),
        ):
            with self.subTest(method=method, body=body), self.assertRaises(ValueError):
                api.validate_request(method, "/v1/apps/123", body, allowed)
        api.validate_request("PATCH", "/v1/apps/123", b'{"data": {}}', True)

    def test_guard_fails_before_credentials_or_network(self):
        with patch.object(api, "make_token") as token, patch.object(api, "request") as request:
            with patch("sys.stderr", new_callable=io.StringIO):
                self.assertEqual(api.main(["/v1/apps/123", "--method", "PATCH"]), 1)
            token.assert_not_called()
            request.assert_not_called()

    def test_synthetic_jwt_signature_and_expiry(self):
        key = ec.generate_private_key(ec.SECP256R1())
        pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption())
        token = api.make_token("SYNTHETIC", "test-issuer", pem, 1000)
        header, claims, signature = token.split(".")
        decode = lambda value: base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
        self.assertEqual(json.loads(decode(header))["alg"], "ES256")
        self.assertEqual(json.loads(decode(claims)), {
            "iss": "test-issuer", "iat": 1000, "exp": 1300, "aud": "appstoreconnect-v1"
        })
        raw = decode(signature)
        self.assertEqual(len(raw), 64)
        der = encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
        key.public_key().verify(der, (header + "." + claims).encode(), ec.ECDSA(hashes.SHA256()))

    def test_empty_success_response(self):
        with patch.object(api.urllib.request, "build_opener") as build:
            response = build.return_value.open.return_value.__enter__.return_value
            response.status, response.read.return_value = 204, b""
            self.assertEqual(api.request("PATCH", "/v1/apps/123", b"{}", "synthetic"), {"status": 204})
            req = build.return_value.open.call_args.args[0]
            self.assertEqual(req.full_url, "https://api.appstoreconnect.apple.com/v1/apps/123")
            self.assertEqual(req.get_method(), "PATCH")

    def test_redirect_never_forwards_credentials(self):
        self.assertIsNone(api.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.com"))


if __name__ == "__main__":
    unittest.main()
