"""Synthetic browser checks against the actual Worker origin and its HTTP policies."""
import hashlib
import json
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[2]
origin = sys.argv[1] if len(sys.argv) == 2 else 'http://127.0.0.1:8787/'
target = urlsplit(origin)
if (target.path not in {'', '/'} or target.query or target.fragment or target.username or target.password
        or not (target.scheme == 'https' or (target.scheme == 'http' and target.hostname in {'127.0.0.1', 'localhost', '::1'}))):
    raise SystemExit('Use a plain HTTPS origin or a local loopback origin without credentials or data')
engine = os.environ.get('BROWSER', 'chromium')
if engine not in {'chromium', 'webkit'}:
    raise SystemExit('BROWSER must be chromium or webkit')
output = ROOT / '.build/web-worker' / f'browser-{engine}'
output.mkdir(parents=True, exist_ok=True)
result = output / 'report.json'
result.unlink(missing_ok=True)
password = json.loads((ROOT / 'shared/contracts/backup/encryption-v1.json').read_text())['uiPhraseASCII']
assets = json.loads((ROOT / '.build/web-worker/asset-manifest.json').read_text())['assets']
html_hash = next(asset['sha256'] for asset in assets if asset['path'] == 'index.html')

with sync_playwright() as pw:
    options = {'headless': True}
    if engine == 'chromium' and os.environ.get('CHROMIUM_EXECUTABLE'):
        options['executable_path'] = os.environ['CHROMIUM_EXECUTABLE']
    browser = getattr(pw, engine).launch(**options)
    context = browser.new_context(viewport={'width': 390, 'height': 844}, accept_downloads=True)
    requests, errors = [], []
    context.on('request', lambda request: requests.append((request.url, request.method)))
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    try:
        response = page.goto(origin)
        assert response.status == 200
        assert "frame-ancestors 'self'" in response.headers['content-security-policy']
        assert 'no-transform' in response.headers['cache-control']
        assert hashlib.sha256(response.body()).hexdigest() == html_hash, 'The browser must receive the exact reviewed HTML without edge-injected scripts'
        expect(page.get_by_role('heading', name='Is Your Paycheck Correct?')).to_be_visible()
        page.get_by_role('button', name='Pay rules', exact=True).click()
        page.get_by_label('Hourly rate', exact=True).fill('19.99')
        page.get_by_label('Per diem per worked local date', exact=True).fill('80')
        page.get_by_label('I confirmed these inputs against my pay rules.', exact=True).check()
        page.get_by_role('button', name='Save a new profile', exact=True).click()
        page.get_by_label('First work date', exact=True).fill('2026-10-01')
        page.get_by_label('Last work date (included)', exact=True).fill('2026-10-14')
        page.get_by_label('Payroll timezone', exact=True).fill('America/Chicago')
        page.get_by_role('button', name='Review pay period', exact=True).click()
        page.get_by_role('button', name='Start period', exact=True).click()
        page.get_by_label('Start', exact=True).fill('2026-10-01T08:00')
        page.get_by_label('End', exact=True).fill('2026-10-01T08:30')
        page.get_by_role('button', name='Save work', exact=True).click()
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        page.get_by_label('Confirmed paycheck gross', exact=True).fill('9.00')
        page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
        page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
        page.get_by_label('Reported first work date', exact=True).fill('2026-10-01')
        page.get_by_label('Reported last work date (included)', exact=True).fill('2026-10-14')
        page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
        page.get_by_role('button', name='Review comparison', exact=True).click()
        expect(page.locator('#audit-preview')).to_contain_text('Possible shortfall')
        page.get_by_role('button', name='Save this check', exact=True).click()
        tools = page.locator('[data-audit-tools]').first
        tools.get_by_role('button', name='Review evidence report', exact=True).click()
        report = tools.frame_locator('iframe')
        expect(report.get_by_role('heading', name='Paycheck Audit: LinePay evidence report', exact=True)).to_be_visible()
        assert 'USD 1.00' in report.locator('body').inner_text()
        assert 'Arial' in report.locator('body').evaluate('(element) => getComputedStyle(element).fontFamily')
        with page.expect_download() as downloaded:
            tools.get_by_role('button', name='Download reviewed report (HTML)', exact=True).click()
        html = output / 'synthetic-report.html'
        downloaded.value.save_as(html)
        printed = context.new_page()
        printed.set_content(html.read_text())
        expect(printed.get_by_role('heading', name='Paycheck Audit: LinePay evidence report', exact=True)).to_be_visible()
        printed.emulate_media(media='print')
        if engine == 'chromium':
            printed.pdf(path=str(output / 'synthetic-report.pdf'), prefer_css_page_size=True)
        printed.close()
        page.get_by_role('button', name='Backup', exact=True).click()
        page.get_by_label('New backup password', exact=True).fill(password)
        page.get_by_label('Repeat password', exact=True).fill(password)
        with page.expect_download() as downloaded:
            page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        backup = output / 'synthetic.linepaybackup'
        downloaded.value.save_as(backup)
        assert backup.read_bytes().startswith(b'LPBENC01')
        page.evaluate('() => navigator.serviceWorker.ready.then(() => true)')
        page.reload()
        page.wait_for_function('() => !!navigator.serviceWorker.controller')
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        assert not errors, errors
        for url, method in requests:
            if url.startswith('blob:'):
                continue
            request = urlsplit(url)
            assert request.scheme + '://' + request.netloc == target.scheme + '://' + target.netloc, url
            assert request.query == '' and method == 'GET', (url, method)
        page.screenshot(path=str(output / 'worker-journey.png'), full_page=True)
        result.write_text(json.dumps({'status': 'passed', 'origin': origin, 'browser': engine,
            'checks': ['exact synthetic wages and saved comparison', 'sandboxed Blob report with HTTP CSP',
                       'report HTML download and print layout', 'encrypted backup download',
                       'service-worker control and retained local records after reload', 'same-origin GET-only requests']}, indent=2) + '\n')
        print(f'Worker browser checks passed ({engine}) at {origin}')
    except Exception:
        page.screenshot(path=str(output / 'failure.png'), full_page=True)
        raise
    finally:
        context.close()
        browser.close()
