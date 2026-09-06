"""The submission boundary uses synthetic payloads and mocked credentials/network only."""
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("asc_legal_api", Path(__file__).parents[1] / "asc-api.py")
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)


class LegalAPIBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.key = self.root / "synthetic-key"
        self.key.write_text("TEST-ONLY NOT A KEY")
        self.body = self.root / "body.json"
        self.body.write_text('{"data":{"type":"reviewSubmissions","attributes":{"submitted":true}}}')
        self.env = {"ASC_KEY_ID": "fixture", "ASC_ISSUER_ID": "fixture",
                    "ASC_PRIVATE_KEY_PATH": str(self.key)}

    def test_allow_write_alone_cannot_submit_even_with_credentials(self):
        with patch.dict(os.environ, self.env), patch.object(api, "make_token", return_value="mocked") as token, \
             patch.object(api, "request", return_value={}) as request, \
             patch("sys.stderr", new_callable=io.StringIO), patch("sys.stdout", new_callable=io.StringIO):
            result = api.main(["/v1/reviewSubmissions/123", "--method", "PATCH",
                               "--body", str(self.body), "--allow-write"])
        self.assertEqual(result, 1)
        token.assert_not_called()
        request.assert_not_called()

    def test_get_remains_read_only_without_release_approvals(self):
        with patch.dict(os.environ, self.env), patch.object(api, "make_token", return_value="mocked"), \
             patch.object(api, "request", return_value={}) as request, \
             patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(api.main(["/v1/builds"]), 0)
        request.assert_called_once()

    def test_encoded_paths_duplicate_fields_and_automatic_release_are_rejected(self):
        for path, payload in (
            ("/v1/appStoreVersionRelease%52equests", b'{"data":{}}'),
            ("/v1/appStoreVersions/123", b'{"data":{"attributes":{"releaseType":"AFTER_APPROVAL"}}}'),
            ("/v1/appStoreVersions/123", b'{"data":{"type":"appStoreVersions","id":"123","attributes":{"releaseType":"AFTER_APPROVAL","releaseType":"MANUAL"}}}'),
        ):
            with self.subTest(path=path), self.assertRaises(ValueError):
                api.validate_request("PATCH", path, payload, True)

    def test_exact_manual_safety_hold_remains_available(self):
        self.body.write_text(json.dumps({"data": {"type": "appStoreVersions", "id": "123",
                                                 "attributes": {"releaseType": "MANUAL"}}}))
        with patch.dict(os.environ, self.env), patch.object(api, "make_token", return_value="mocked"), \
             patch.object(api, "request", return_value={}) as request, \
             patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(api.main(["/v1/appStoreVersions/123", "--method", "PATCH",
                                       "--body", str(self.body), "--allow-write"]), 0)
        request.assert_called_once()
