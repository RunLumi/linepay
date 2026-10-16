"""Real browser local-only journeys, using synthetic work and the public fixture password."""
import functools
import json
import os
from pathlib import Path
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[3]
WEB = ROOT / 'apps/web'
ENGINE = os.environ.get('BROWSER', 'chromium')
if ENGINE not in {'chromium', 'webkit'}:
    raise SystemExit('BROWSER must be chromium or webkit')
OUTPUT = ROOT / '.build/web-e2e' / ENGINE
OUTPUT.mkdir(parents=True, exist_ok=True)
PASSWORD = json.loads((ROOT / 'shared/contracts/backup/encryption-v1.json').read_text())['uiPhraseASCII']
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass
server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(WEB)))
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
origin = f'http://127.0.0.1:{server.server_port}'
checks = []

def profile(page, rate):
    page.get_by_role('button', name='Pay rules', exact=True).click()
    page.get_by_label('Hourly rate', exact=True).fill(rate)
    page.get_by_label('Per diem per worked local date', exact=True).fill('80')
    page.get_by_label('I confirmed these inputs against my pay rules.', exact=True).check()
    page.get_by_role('button', name='Save a new profile', exact=True).click()

def read_state(page):
    return page.evaluate("async () => (await (await import('./src/state.mjs')).openStore()).read()")

with sync_playwright() as pw:
    options = {'headless': True}
    if ENGINE == 'chromium' and os.environ.get('CHROMIUM_EXECUTABLE'):
        options['executable_path'] = os.environ['CHROMIUM_EXECUTABLE']
    browser = getattr(pw, ENGINE).launch(**options)
    context = browser.new_context(viewport={'width': 390, 'height': 844}, accept_downloads=True)
    errors, requests = [], []
    context.on('request', lambda r: requests.append((r.url, r.method)))
    page = context.new_page()
    page.on('pageerror', lambda e: errors.append(str(e)))
    try:
        page.goto(origin + '/')
        expect(page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        profile(page, '19.99')
        page.get_by_label('First work date', exact=True).fill('2026-10-01')
        page.get_by_label('Last work date (included)', exact=True).fill('2026-10-14')
        page.get_by_label('Payroll timezone', exact=True).fill('America/Chicago')
        page.get_by_role('button', name='Start period', exact=True).click()
        page.get_by_label('Start', exact=True).fill('2026-10-01T08:00')
        page.get_by_label('End', exact=True).fill('2026-10-01T08:30')
        page.get_by_role('button', name='Save work', exact=True).click()
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        checks.append('profile → explicit period/timezone → actual work → exact 19.99 half-hour cent')
        page.get_by_label('Confirmed paycheck gross', exact=True).fill('9.00')
        page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
        page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
        page.get_by_label('I confirmed the paycheck covers this exact work period.', exact=True).check()
        page.get_by_role('button', name='Review comparison', exact=True).click()
        expect(page.locator('#audit-preview')).to_contain_text('Possible shortfall')
        assert len(read_state(page)['periods'][0]['audits']) == 0
        page.get_by_role('button', name='Save this check', exact=True).click()
        assert read_state(page)['periods'][0]['audits'][0]['assessment']['difference'] == '1.00'
        checks.append('review creates no record; explicit confirmation saves immutable 1.00 possible difference')
        page.get_by_role('button', name='Close this period', exact=True).click()
        page.get_by_role('button', name='Confirm close period', exact=True).click()
        profile(page, '25')
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        assert read_state(page)['periods'][0]['rule']['hourlyRate'] == '19.99'
        assert read_state(page)['periods'][0]['closedCalculation']['wages'] == '10.00'
        checks.append('new rule profile preserves closed work/calculation/check snapshots')
        wage_records = read_state(page)['periods']
        page.get_by_role('button', name='Benefits', exact=True).click()
        page.get_by_role('button', name='New fund check', exact=True).click()
        page.get_by_label('Fund name', exact=True).fill('SYNTHETIC pension fund')
        page.get_by_label('Contribution start', exact=True).fill('2026-10-01')
        page.get_by_label('Contribution end (exclusive)', exact=True).fill('2026-11-01')
        page.get_by_label('Contribution timezone', exact=True).fill('America/Chicago')
        page.get_by_role('button', name='Use full fund period for this segment', exact=True).click()
        page.get_by_label('Confirmed rate or percentage', exact=True).fill('8.75')
        page.get_by_label('Explicit eligible quantity', exact=True).fill('40')
        page.get_by_label('I confirmed this rate is effective throughout this eligibility segment.', exact=True).check()
        page.get_by_label('These segments cover all eligible work or earnings for this fund period.', exact=True).check()
        page.get_by_label('Explicit eligible quantity', exact=True).fill('41')
        assert not page.get_by_label('I confirmed this rate is effective throughout this eligibility segment.', exact=True).is_checked()
        assert not page.get_by_label('These segments cover all eligible work or earnings for this fund period.', exact=True).is_checked()
        page.get_by_label('Explicit eligible quantity', exact=True).fill('40')
        page.get_by_label('I confirmed this rate is effective throughout this eligibility segment.', exact=True).check()
        page.get_by_label('These segments cover all eligible work or earnings for this fund period.', exact=True).check()
        checks.append('material eligibility edit clears prior rate/effective-scope and complete-eligibility confirmations')
        page.get_by_label('Clause, page and source-version note (optional)', exact=True).fill('SYNTHETIC clause <section>not markup</section>')
        page.get_by_role('button', name='Review fund check', exact=True).click()
        expect(page.locator('#fund-preview')).to_contain_text('Not verified')
        assert read_state(page)['benefitChecks'] == []
        page.get_by_role('button', name='Save this fund check', exact=True).click()
        first_fund = read_state(page)['benefitChecks'][0]['revisions'][0]
        assert first_fund['result']['amount'] == '350.00' and first_fund['result']['paid'] is None
        assert read_state(page)['periods'] == wage_records
        checks.append('fund eligibility preview writes nothing; missing-statement 350 expectation saved separately from cash wages')
        page.get_by_role('button', name='Add revised check', exact=True).click()
        page.get_by_label('I confirmed this rate is effective throughout this eligibility segment.', exact=True).check()
        page.get_by_label('These segments cover all eligible work or earnings for this fund period.', exact=True).check()
        page.get_by_label('Statement review state', exact=True).select_option('confirmed')
        page.get_by_text('Statement dates, currency, amount and units', exact=True).click()
        page.get_by_label('Statement start', exact=True).fill('2026-10-01')
        page.get_by_label('Statement end (exclusive)', exact=True).fill('2026-11-01')
        page.get_by_label('Statement timezone', exact=True).fill('America/Chicago')
        page.get_by_label('Statement employer contribution (optional)', exact=True).fill('350.001')
        page.get_by_label('Statement eligible quantity (optional)', exact=True).fill('40')
        page.get_by_label('Statement quantity basis', exact=True).select_option('eligibleHour')
        page.get_by_label('I checked the fund identity, dates, currency and each entered value against the source.', exact=True).check()
        page.get_by_role('button', name='Review fund check', exact=True).click()
        expect(page.locator('#fund-preview')).to_contain_text('USD -0.001')
        assert len(read_state(page)['benefitChecks'][0]['revisions']) == 1
        page.get_by_label('Statement employer contribution (optional)', exact=True).fill('350.002')
        expect(page.get_by_role('button', name='Save this fund check', exact=True)).to_have_count(0)
        assert not page.get_by_label('I checked the fund identity, dates, currency and each entered value against the source.', exact=True).is_checked()
        assert len(read_state(page)['benefitChecks'][0]['revisions']) == 1
        page.get_by_label('Statement employer contribution (optional)', exact=True).fill('350.001')
        page.get_by_label('I checked the fund identity, dates, currency and each entered value against the source.', exact=True).check()
        page.get_by_role('button', name='Review fund check', exact=True).click()
        expect(page.locator('#fund-preview')).to_contain_text('USD -0.001')
        checks.append('material statement edit invalidates the unsaved preview and prior source confirmation')
        page.get_by_role('button', name='Save this fund check', exact=True).click()
        fund = read_state(page)['benefitChecks'][0]
        assert fund['revisions'][0] == first_fund and fund['revisions'][1]['result']['difference'] == '-0.001'
        assert read_state(page)['periods'] == wage_records
        assert page.locator('main section').count() == 0, 'Escaped reference note became markup'
        checks.append('later confirmed 350.001 statement appends exact -0.001 revision and preserves original unknown check/source text')
        page.get_by_role('button', name='Backup', exact=True).click()
        page.get_by_label('New backup password', exact=True).fill(PASSWORD)
        page.get_by_label('Repeat password', exact=True).fill(PASSWORD)
        with page.expect_download() as event:
            page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        backup = OUTPUT / 'synthetic-web.linepaybackup'
        event.value.save_as(backup)
        expect(page.get_by_label('New backup password', exact=True)).to_have_value('')
        assert backup.read_bytes().startswith(b'LPBENC01')
        baseline = read_state(page)
        page.get_by_label('Protected web backup', exact=True).set_input_files(backup)
        page.get_by_label('Backup password', exact=True).fill('incorrect test password')
        page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        expect(page.locator('#status')).to_contain_text('Could not unlock')
        assert read_state(page) == baseline
        checks.append('actual download; wrong password leaves all local state unchanged and clears password')
        page.get_by_role('button', name='Review removal', exact=True).click()
        page.get_by_role('button', name='Confirm remove all local records', exact=True).click()
        assert read_state(page)['periods'] == []
        page.get_by_label('Protected web backup', exact=True).set_input_files(backup)
        page.get_by_label('Backup password', exact=True).fill(PASSWORD)
        page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        expect(page.locator('#restore-preview')).to_contain_text('records unchanged')
        assert read_state(page)['periods'] == []
        page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        restored = read_state(page)
        assert restored['periods'] == baseline['periods'] and restored['profiles'] == baseline['profiles']
        assert restored['benefitChecks'] == baseline['benefitChecks']
        assert restored['revision'] > baseline['revision']
        checks.append('synthetic destructive reset → authenticated inspection → separate replace restores exact snapshots')
        page.get_by_role('button', name='History', exact=True).click()
        page.get_by_role('button', name='Open record', exact=True).click()
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        page.get_by_text('Saved paycheck checks', exact=True).scroll_into_view_if_needed()
        page.screenshot(path=str(OUTPUT / 'restored-ledger.png'), full_page=True)
        page.emulate_media(color_scheme='dark', reduced_motion='reduce')
        page.set_viewport_size({'width': 320, 'height': 900})
        page.evaluate("document.documentElement.style.fontSize='26px'")
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(OUTPUT / 'large-dark-ledger.png'), full_page=True)
        page.evaluate('scrollTo(0,0)')
        page.screenshot(path=str(OUTPUT / 'large-dark-viewport.png'))
        checks.append('320px dark/reduced-motion with enlarged text: no horizontal page overflow')
        # A second genuine tab has an old in-memory revision. Its write must abort atomically.
        second = context.new_page()
        second.goto(origin + '/')
        expect(second.get_by_role('heading', name='Expected cash wages')).to_be_visible()
        profile(page, '30')
        profile(second, '40')
        expect(second.locator('#status')).to_contain_text('Another tab changed these records')
        saved = read_state(page)
        assert saved['profiles'][-1]['hourlyRate'] == '30' and len(saved['profiles']) == 3
        checks.append('stale-tab save aborts without overwriting the newer committed state')
        second.close()
        # An actual prior-version payload is encrypted and restored in an isolated browser context.
        legacy_context = browser.new_context(accept_downloads=True)
        legacy_context.on('request', lambda r: requests.append((r.url, r.method)))
        legacy_page = legacy_context.new_page()
        legacy_page.on('pageerror', lambda e: errors.append(str(e)))
        legacy_page.goto(origin + '/')
        expect(legacy_page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        prior = json.loads((WEB / 'tests/fixtures/web-state-v1.json').read_text())
        protected = legacy_page.evaluate("""async ({state,password}) => {
          const {encryptBackup}=await import('./src/backup.mjs');
          return Array.from(await encryptBackup(new TextEncoder().encode(JSON.stringify({format:'com.streamentry.linepay.web.snapshot',version:1,state})),password));
        }""", {'state': prior, 'password': PASSWORD})
        prior_file = OUTPUT / 'synthetic-prior-v1.linepaybackup'
        prior_file.write_bytes(bytes(protected))
        legacy_page.get_by_role('button', name='Backup', exact=True).click()
        legacy_page.get_by_label('Protected web backup', exact=True).set_input_files(prior_file)
        legacy_page.get_by_label('Backup password', exact=True).fill(PASSWORD)
        legacy_page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        expect(legacy_page.locator('#restore-preview')).to_contain_text('records unchanged')
        assert read_state(legacy_page)['periods'] == []
        legacy_page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        migrated = read_state(legacy_page)
        assert migrated['version'] == 2 and migrated['benefitChecks'] == []
        assert migrated['periods'] == prior['periods'] and migrated['profiles'] == prior['profiles']
        legacy_page.get_by_role('button', name='Pay', exact=True).click()
        expect(legacy_page.locator('.answer')).to_have_text('USD 400.00')
        legacy_context.close()
        checks.append('actual encrypted schema-v1 backup inspects without mutation then migrates through explicit browser restore with wages/history unchanged')
        page.evaluate('navigator.serviceWorker.ready.then(() => true)')
        page.reload()
        page.wait_for_function('navigator.serviceWorker.controller !== null')
        # WebKit's offline-emulation flag rejects even literal worker responses
        # (upstream Playwright #42775). Stop the real origin for both engines instead.
        server.shutdown()
        server.server_close()
        negative = browser.new_context(service_workers='block')
        try:
            negative.new_page().goto(origin + '/', timeout=5000)
        except Exception:
            pass
        else:
            raise AssertionError('No-worker control unexpectedly loaded the stopped origin')
        finally:
            negative.close()
        response = page.reload()
        assert response.from_service_worker, 'Offline navigation did not come from the worker'
        expect(page.get_by_role('heading', name='Expected cash wages')).to_be_visible()
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        assert read_state(page)['periods'] == baseline['periods']
        assert read_state(page)['benefitChecks'] == baseline['benefitChecks']
        page.get_by_role('button', name='Benefits', exact=True).click()
        page.get_by_role('button', name='Open fund check', exact=True).click()
        expect(page.get_by_text('USD -0.001', exact=True)).to_be_visible()
        page.evaluate("document.documentElement.style.fontSize='26px'")
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.evaluate('scrollTo(0,0)')
        page.screenshot(path=str(OUTPUT / 'fund-history-dark-viewport.png'))
        page.locator('[data-fund-revision="2"]').get_by_text('Expected employer contribution', exact=True).scroll_into_view_if_needed()
        page.screenshot(path=str(OUTPUT / 'fund-precision-dark-viewport.png'))
        checks.append('origin stopped: worker-served app/history reload succeeds; fresh no-worker control fails')
        # Percentage quantity is eligible earnings, not a percentage or worked-hour count.
        # Exercise the actual editor offline and leave the preview unsaved.
        page.get_by_role('button', name='New fund check', exact=True).click()
        page.get_by_label('Fund name', exact=True).fill('SYNTHETIC earnings-based fund')
        page.get_by_label('Contribution start', exact=True).fill('2026-10-01')
        page.get_by_label('Contribution end (exclusive)', exact=True).fill('2026-11-01')
        page.get_by_label('Contribution timezone', exact=True).fill('America/Chicago')
        page.get_by_role('button', name='Use full fund period for this segment', exact=True).click()
        page.get_by_label('Contribution basis', exact=True).select_option('percentOfEligibleEarnings')
        page.get_by_label('Confirmed rate or percentage', exact=True).fill('5')
        page.get_by_label('Explicit eligible quantity', exact=True).fill('1234.56')
        page.get_by_label('I confirmed this rate is effective throughout this eligibility segment.', exact=True).check()
        page.get_by_label('These segments cover all eligible work or earnings for this fund period.', exact=True).check()
        page.get_by_role('button', name='Review fund check', exact=True).click()
        expect(page.locator('#fund-preview')).to_contain_text('USD 61.73')
        expect(page.locator('#fund-preview').get_by_text('Explicit eligible earnings', exact=True)).to_be_visible()
        expect(page.locator('#fund-preview').get_by_text('USD 1234.56', exact=True)).to_be_visible()
        assert read_state(page)['benefitChecks'] == baseline['benefitChecks']
        page.locator('#fund-preview').get_by_text('Explicit eligible earnings', exact=True).scroll_into_view_if_needed()
        page.screenshot(path=str(OUTPUT / 'fund-percent-preview-dark-viewport.png'))
        checks.append('offline percentage editor labels quantity as explicit eligible earnings in currency and preview leaves saved history untouched')
        assert not errors, errors
        assert all(url.startswith(origin + '/') and method == 'GET' for url, method in requests), requests
        checks.append('all observed network traffic is same-origin app-shell GETs; no pay-data requests')
        report = {'passed': True, 'browser': ENGINE, 'browserVersion': browser.version, 'checks': checks,
                  'scope': 'Synthetic local browser workflow. No deployment, actual OS Files delivery, native snapshot migration, installed-PWA/physical-device or App Store release proof.'}
        (OUTPUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
    except Exception:
        page.screenshot(path=str(OUTPUT / 'failure.png'), full_page=True)
        (OUTPUT / 'failure.txt').write_text(page.locator('body').inner_text())
        raise
    finally:
        browser.close()
        server.shutdown()
        server.server_close()
