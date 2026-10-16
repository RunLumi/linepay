"""Optional real-browser backup-envelope conformance. Uses only public synthetic fixture data."""
import hashlib
import json
import os
from pathlib import Path

from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
fixture = root / "shared/contracts/backup/encryption-v1.json"
vector = json.loads(fixture.read_text())
engine = os.environ.get("BROWSER", "chromium")
if engine not in {"chromium", "webkit"}:
    raise SystemExit("BROWSER must be chromium or webkit")
script = """async vector => {
  if (!isSecureContext || !crypto.subtle) throw Error('A secure browser context is required');
  const fromHex = hex => Uint8Array.from(hex.match(/../g), pair => parseInt(pair, 16));
  const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
  const encoded = fromHex(vector.encodedHex), header = encoded.slice(0, 44);
  const salt = encoded.slice(12, 28), nonce = encoded.slice(28, 40);
  const plain = new TextEncoder().encode(vector.plaintextUTF8);
  const derive = async password => {
    const base = await crypto.subtle.importKey('raw', new TextEncoder().encode(password.normalize('NFC')),
      'PBKDF2', false, ['deriveKey']);
    return crypto.subtle.deriveKey({name:'PBKDF2', salt, iterations:600000, hash:'SHA-256'},
      base, {name:'AES-GCM', length:256}, false, ['encrypt','decrypt']);
  };
  const key = await derive(vector.password);
  const params = {name:'AES-GCM', iv:nonce, additionalData:header, tagLength:128};
  const encrypted = await crypto.subtle.encrypt(params, key, plain);
  if (hex(encrypted) !== hex(encoded.slice(44))) throw Error('Ciphertext/tag differs from independent vector');
  const decrypted = await crypto.subtle.decrypt(params, key, encoded.slice(44));
  if (hex(decrypted) !== hex(plain)) throw Error('Plaintext mismatch');
  const rejects = async operation => { try { await operation; } catch { return true; } return false; };
  const damaged = encoded.slice(44); damaged[damaged.length-1] ^= 1;
  if (!await rejects(crypto.subtle.decrypt(params, key, damaged))) throw Error('Damaged tag accepted');
  const changedHeader = header.slice(); changedHeader[12] ^= 1;
  if (!await rejects(crypto.subtle.decrypt({...params, additionalData:changedHeader}, key, encoded.slice(44))))
    throw Error('Changed authenticated header accepted');
  if (!await rejects(crypto.subtle.decrypt(params, await derive(vector.password+' wrong'), encoded.slice(44))))
    throw Error('Wrong password accepted');
  return {secureContext:isSecureContext, vectorMatched:true, roundTrip:true, tagRejected:true,
    headerRejected:true, wrongPasswordRejected:true};
}"""
with sync_playwright() as p:
    options = {"headless": True}
    if engine == "chromium" and os.environ.get("CHROMIUM_EXECUTABLE"):
        options.update(executable_path=os.environ["CHROMIUM_EXECUTABLE"], args=["--no-sandbox"])
    browser = getattr(p, engine).launch(**options)
    try:
        context = browser.new_context()
        # Fulfilled locally before any network operation; .invalid is reserved test syntax.
        context.route("**/*", lambda route: route.fulfill(status=200, content_type="text/html",
            body="<!doctype html><title>Synthetic backup crypto conformance</title>")
            if route.request.url == "https://backup-fixture.invalid/" else route.abort())
        page = context.new_page()
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto("https://backup-fixture.invalid/")
        result = page.evaluate(script, vector)
        assert not errors, errors
        result.update(browser=engine, browserVersion=browser.version,
            fixtureSHA256=hashlib.sha256(fixture.read_bytes()).hexdigest(), passed=True,
            scope="Browser WebCrypto transport conformance only; not full PWA or Android restore")
        output = root / ".build/backup-crypto-browser"
        output.mkdir(parents=True, exist_ok=True)
        (output / f"{engine}.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result))
    finally:
        browser.close()
