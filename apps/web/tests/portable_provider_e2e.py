"""Actual native-provider intake/export through the existing local browser UI.

Requires PORTABLE_PROVIDER_MANIFEST pointing to a source-bound synthetic native capture.
No fixture encryption substitutes for the provider's protected input bytes.
"""
import functools
import hashlib
import json
import os
import re
from urllib.parse import urlsplit
from pathlib import Path
import subprocess
import threading
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[3]
WEB = ROOT / 'apps/web'
CAPTURE = Path(os.environ['PORTABLE_PROVIDER_MANIFEST'])
provider = json.loads(CAPTURE.read_text())
protected = CAPTURE.parent / 'ios-provider.linepaybackup'
plaintext = CAPTURE.parent / 'plaintext.json'
sha = lambda file: hashlib.sha256(file.read_bytes()).hexdigest()
assert sha(protected) == provider['providerSHA256']
assert sha(plaintext) == provider['plaintextSHA256']
fixture = json.loads(plaintext.read_text())
phrase = provider['syntheticOutputPassword']
source_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()

def tree_hash(runtime=False):
    digest = hashlib.sha256()
    for file in sorted(WEB.rglob('*')):
        if not file.is_file() or '__pycache__' in file.parts:
            continue
        relative = file.relative_to(WEB)
        if runtime and ('tests' in relative.parts or file.suffix not in {'.mjs', '.js', '.html', '.css', '.png', '.svg', '.webmanifest'}):
            continue
        digest.update(str(relative).encode())
        digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()

runtime_sha = tree_hash(True)
source_sha = tree_hash()
assert runtime_sha == os.environ.get('EXPECTED_WEB_RUNTIME_SHA256', runtime_sha)
current_source = [period for period in fixture['periods'] if period['isCurrent'] is True]
assert len(current_source) == 1
assert current_source[0]['profileRef'] != fixture['activeProfileRef']
assert len(fixture['paycheckReceipts']) == 3
fresh = fixture['paycheckReceipts'][-1]
assert fresh['producer']['client'] == 'ios'
assert fresh['assessment']['expectedGross'] == {'amount': '1000', 'currency': 'USD'}
assert fresh['assessment']['paidGross'] == {'amount': '1000', 'currency': 'USD'}
assert fresh['assessment']['difference'] == {'amount': '0', 'currency': 'USD'}
assert fresh['assessment']['verdict'] == 'needsReview'
assert fresh['assessment']['weeklyReviewRefs'] is None
assert 'weeklyReviewRefs' in fresh['assessment']['fieldsNotRecorded']

def validated_https_origin(value):
    parsed = urlsplit(value)
    label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    if (not re.fullmatch(r'https://[a-z0-9.-]+/?', value) or parsed.scheme != 'https' or
        parsed.hostname is None or parsed.netloc != parsed.hostname or parsed.hostname.replace('.', '').isdigit() or
        len(parsed.hostname) > 253 or not re.fullmatch(label + r'(?:\.' + label + r')+', parsed.hostname) or
        parsed.path not in {'', '/'} or parsed.query or parsed.fragment or '?' in value or '#' in value):
        raise ValueError('Provider origin must be an HTTPS root with a DNS hostname and no credentials, port, path, query or fragment.')
    return 'https://' + parsed.hostname

class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

class LocalServer(ThreadingHTTPServer):
    request_queue_size = 64

engine = os.environ.get('BROWSER', 'chromium')
output = Path(os.environ.get('PORTABLE_PROVIDER_OUTPUT', ROOT / '.build/web-provider-e2e')) / engine
output.mkdir(parents=True, exist_ok=True)
remote_origin = os.environ.get('PORTABLE_PROVIDER_ORIGIN')
server = None
if remote_origin:
    origin = validated_https_origin(remote_origin)
else:
    server = LocalServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(WEB)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = f'http://127.0.0.1:{server.server_port}'
with sync_playwright() as pw:
    options = {'headless': True}
    if engine == 'chromium' and os.environ.get('CHROMIUM_EXECUTABLE'):
        options['executable_path'] = os.environ['CHROMIUM_EXECUTABLE']
    browser = getattr(pw, engine).launch(**options)
    context = browser.new_context(viewport={'width': 390, 'height': 844}, accept_downloads=True, service_workers='block' if remote_origin else 'allow')
    allowed_requests = []
    blocked_requests = []
    if remote_origin:
        allowed_paths = {'/', '/favicon.ico'} | {'/' + str(file.relative_to(WEB)) for file in WEB.rglob('*') if file.is_file() and 'tests' not in file.relative_to(WEB).parts and file.suffix in {'.mjs', '.js', '.html', '.css', '.png', '.svg', '.webmanifest'}}
        def guard(route):
            request = route.request
            parsed = urlsplit(request.url)
            allowed = (request.method == 'GET' and request.post_data is None and
                       parsed.scheme + '://' + parsed.netloc == origin and
                       parsed.path in allowed_paths and not parsed.query and not parsed.fragment)
            if allowed:
                allowed_requests.append({'method': request.method, 'path': parsed.path})
                route.continue_()
            else:
                blocked_requests.append({'method': request.method, 'resourceType': request.resource_type})
                route.abort('blockedbyclient')
        context.route('**/*', guard)
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    def read():
        return page.evaluate("async()=>await(await(await import('./src/state.mjs')).openStore()).read()")
    def inspect(file):
        page.get_by_label('Protected web backup', exact=True).set_input_files(file)
        page.get_by_label('Backup password', exact=True).fill(phrase)
        page.get_by_role('button', name='Unlock and inspect', exact=True).click()
    try:
        served_runtime_sha = None
        page.goto(origin)
        if remote_origin:
            files = [file for file in sorted(WEB.rglob('*')) if file.is_file() and 'tests' not in file.relative_to(WEB).parts and file.suffix in {'.mjs', '.js', '.html', '.css', '.png', '.svg', '.webmanifest'}]
            paths = [str(file.relative_to(WEB)) for file in files]
            received = page.evaluate("""async paths=>Object.fromEntries(await Promise.all(paths.map(async path=>{const response=await fetch('/'+path,{signal:AbortSignal.timeout(30000)});if(!response.ok)throw Error('Asset verification failed: '+path);const hash=await crypto.subtle.digest('SHA-256',await response.arrayBuffer());return [path,Array.from(new Uint8Array(hash),x=>x.toString(16).padStart(2,'0')).join('')];})))""", paths)
            served = hashlib.sha256()
            for file, relative in zip(files, paths):
                assert received[relative] == sha(file), relative
                served.update(relative.encode())
                served.update(bytes.fromhex(received[relative]))
            served_runtime_sha = served.hexdigest()
            assert served_runtime_sha == runtime_sha
        expect(page.get_by_role('heading', name='Is Your Paycheck Correct?', exact=True)).to_be_visible()
        page.get_by_role('button', name='Backup', exact=True).click()
        before = read()
        # The protected negative case keeps the fractional raw token through encryption.
        epoch = fixture['workSnapshots'][0]['work'][0]['startEpochSeconds']
        raw = json.dumps(fixture, separators=(',', ':')).replace('"startEpochSeconds":' + str(epoch), '"startEpochSeconds":' + str(epoch) + '.0000000001', 1)
        assert '.0000000001' in raw
        invalid_bytes = page.evaluate("""async ([raw,phrase])=>Array.from(await(await import('./src/backup.mjs')).encryptBackup(new TextEncoder().encode(raw),phrase))""", [raw, phrase])
        invalid = output / 'fractional-epoch-refusal.linepaybackup'
        invalid.write_bytes(bytes(invalid_bytes))
        inspect(invalid)
        expect(page.locator('#status')).to_have_attribute('role', 'alert')
        expect(page.locator('#status')).to_contain_text('This transfer contains numeric facts this app cannot preserve exactly. No records were replaced.')
        assert read() == before
        assert page.get_by_role('button', name='Replace with inspected backup', exact=True).count() == 0
        inspect(protected)
        expect(page.get_by_role('heading', name='Backup inspected; records unchanged', exact=True)).to_be_visible()
        assert read() == before
        page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        expect(page.locator('#status')).to_contain_text('Inspected backup restored')
        restored = read()
        assert restored['portableArchive']['document'] == fixture
        mappings = restored['portableArchive']['mappings']
        local = lambda kind, identifier: next(row['localID'] for row in mappings if row['entityType'] == kind and row['portableID'] == identifier)
        current = next(period for period in restored['periods'] if not period['closed'])
        assert current['id'] == local('period', current_source[0]['id'])
        assert restored['profiles'][-1]['id'] == local('profile', fixture['activeProfileRef'])
        assert len(current['work']) == 5
        page.get_by_role('button', name='Pay', exact=True).click()
        expect(page.locator('.answer')).to_have_text('USD 1000.00')
        page.get_by_role('button', name='History', exact=True).click()
        receipts = page.locator('[data-portable-receipt]')
        expect(receipts).to_have_count(3)
        for index in range(3):
            receipt = receipts.nth(index)
            receipt.locator('summary').first.click()
            expect(receipt).to_contain_text('Needs review')
            expect(receipt).to_contain_text('Read-only receipt')
            expect(receipt).to_contain_text('1000')
        page.screenshot(path=str(output / 'native-receipts.png'), full_page=True)
        assert read()['portableArchive']['document'] == fixture
        page.get_by_role('button', name='Backup', exact=True).click()
        page.get_by_label('Backup format', exact=True).select_option('portable')
        page.get_by_label('New backup password', exact=True).fill(phrase)
        page.get_by_label('Repeat password', exact=True).fill(phrase)
        with page.expect_download() as download:
            page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        temporary = output / 'actual-download.linepaybackup'
        download.value.save_as(temporary)
        encrypted_sha = sha(temporary)
        retained = output / f'web-provider-{encrypted_sha}.linepaybackup'
        if retained.exists():
            assert retained.read_bytes() == temporary.read_bytes()
        else:
            retained.write_bytes(temporary.read_bytes())
        result = page.evaluate("""async ([bytes,phrase])=>JSON.parse(new TextDecoder().decode(await(await import('./src/backup.mjs')).decryptBackup(new Uint8Array(bytes),phrase)))""", [list(retained.read_bytes()), phrase])
        financial = lambda document: {key: value for key, value in document.items() if key not in {'source', 'exportedAtEpochSeconds'}}
        assert financial(result) == financial(fixture)
        assert result['source']['client'] == 'web'
        retained_plain = retained.with_suffix('.json')
        retained_plain.write_text(json.dumps(result, indent=2) + '\n')
        validation = subprocess.run(['python3', str(ROOT / 'shared/contracts/portable-state/verify.py'), 'check', str(retained_plain), '--target', 'web'], capture_output=True, text=True, check=True)
        inspect(retained)
        expect(page.get_by_role('heading', name='Backup inspected; records unchanged', exact=True)).to_be_visible()
        page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        expect(page.locator('#status')).to_contain_text('Inspected backup restored')
        assert read()['portableArchive']['document'] == result
        page.reload()
        expect(page.locator('.answer')).to_have_text('USD 1000.00')
        assert read()['portableArchive']['document'] == result
        assert not errors, errors
        assert not blocked_requests, blocked_requests
        assert tree_hash(True) == runtime_sha and tree_hash() == source_sha
        report = {'passed': True, 'origin': origin, 'servedRuntimeSHA256': served_runtime_sha, 'remoteNetworkPolicy': 'Service workers blocked; only allowlisted same-origin static-asset GETs without body/query; browser file reads and encryption stay local' if remote_origin else 'Local origin', 'allowedAssetRequests': allowed_requests, 'blockedRequestCount': len(blocked_requests), 'captureIteration': datetime.now(timezone.utc).isoformat(), 'browser': engine, 'browserVersion': browser.version, 'runtimeSHA256': runtime_sha, 'sourceHEAD': source_head, 'dirtyWebSourceAndTestsSHA256': source_sha, 'schemaSHA256': sha(ROOT / 'shared/contracts/portable-state/schema-v1.json'), 'providerManifest': str(CAPTURE), 'providerManifestSHA256': sha(CAPTURE), 'providerInputSHA256': sha(protected), 'providerPlaintextSHA256': sha(plaintext), 'download': str(retained), 'downloadSHA256': encrypted_sha, 'downloadPlaintext': str(retained_plain), 'downloadPlaintextSHA256': sha(retained_plain), 'sharedValidation': validation.stdout.strip(), 'syntheticPhrase': phrase, 'checks': ['protected raw fractional epoch refused before replacement preview; destination unchanged', 'actual iOS protected provider bytes selected through local browser file input; exact provider bytes, no reseal', 'inspect leaves destination unchanged until explicit replace', 'original two and fresh native USD1000 Needs review receipts frozen', 'unknown null+marker remains distinct from known-empty arrays', 'current A and selected future B remain distinct', 'actual browser encrypted download preserves all financial fields', 'shared verifier accepts resulting Web file', 'UI reimport and relaunch preserve the graph']}
        retained.with_suffix('.manifest.json').write_text(json.dumps(report, indent=2) + '\n')
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'passed': True, 'browser': engine, 'download': str(retained), 'runtimeSHA256': runtime_sha}))
    except Exception:
        (output / 'failure.txt').write_text(page.locator('body').inner_text() + '\nErrors: ' + json.dumps(errors))
        page.screenshot(path=str(output / 'failure.png'), full_page=True)
        raise
    finally:
        browser.close()
        if server is not None:
            server.shutdown()
            server.server_close()
