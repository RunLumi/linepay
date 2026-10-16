"""Real browser local-only journeys, using synthetic work and the public fixture password."""
import functools
import hashlib
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
(OUTPUT / 'report.json').unlink(missing_ok=True)
def runtime_hash():
    digest = hashlib.sha256()
    for file in sorted(WEB.rglob('*')):
        if file.is_file() and 'tests' not in file.relative_to(WEB).parts and file.suffix in {'.mjs','.js','.html','.css','.png','.svg','.webmanifest'}:
            digest.update(str(file.relative_to(WEB)).encode())
            digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()
source_hash = runtime_hash()
PASSWORD = json.loads((ROOT / 'shared/contracts/backup/encryption-v1.json').read_text())['uiPhraseASCII']
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass
class LocalServer(ThreadingHTTPServer):
    # Allow concurrent module/caching requests above the default five-slot queue.
    request_queue_size = 64
server = LocalServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(WEB)))
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
    errors, requests, responses, failed_requests, console_errors = [], [], [], [], []
    context.on('request', lambda r: requests.append((r.url, r.method)))
    def observe_context(active_context):
        active_context.on('response', lambda r: responses.append({'url': r.url, 'status': r.status, 'mime': r.headers.get('content-type')}))
        active_context.on('requestfailed', lambda r: failed_requests.append({'url': r.url, 'failure': r.failure}))
        active_context.on('page', lambda active_page: active_page.on('console', lambda item: console_errors.append(item.text) if item.type == 'error' else None))
    observe_context(context)
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
        frozen_check = read_state(page)['periods'][0]['audits'][0]
        check_id = frozen_check['id']
        tools = page.locator(f'[data-audit-tools="{check_id}"]')
        private_note = 'PRIVATE SYNTHETIC — explicación <script>not executable</script>\n' + '\n'.join(f'SYNTHETIC follow-up line {i}: reviewed supporting details, no legal finding.' for i in range(42)) + '\nSYNTHETIC-REPORT-TAIL'
        assert len(private_note) <= 4000
        tools.get_by_label('Follow-up status', exact=True).select_option('corrected')
        tools.get_by_label('What happened?', exact=True).fill(private_note)
        tools.get_by_role('button', name='Save follow-up', exact=True).click()
        assert read_state(page)['periods'][0]['audits'][0] == frozen_check
        assert read_state(page)['resolutionEvents'][0]['status'] == 'corrected'
        assert read_state(page)['resolutionEvents'][0]['note'] == private_note
        checks.append('worker-recorded correction appends follow-up without changing original 1.00 possible-shortfall comparison')
        tools.get_by_role('button', name='Review evidence report', exact=True).click()
        reviewed = tools.frame_locator('iframe')
        expect(reviewed.get_by_role('heading', name='LinePaycheck paycheck evidence report', exact=True)).to_be_visible()
        body = reviewed.locator('body').inner_text()
        assert 'USD 10.00' in body and 'USD 9.00' in body and 'USD 1.00' in body and 'Possible shortfall' in body
        assert 'PRIVATE SYNTHETIC' not in body and 'Correction confirmed by me' not in body and frozen_check['work'][0]['startUTC'] not in body
        assert 'Arial' in reviewed.locator('body').evaluate('(element) => getComputedStyle(element).fontFamily')
        with page.expect_download() as report_event:
            tools.get_by_role('button', name='Download reviewed report (HTML)', exact=True).click()
        minimized = OUTPUT / 'synthetic-minimized-report.html'
        report_event.value.save_as(minimized)
        assert 'PRIVATE SYNTHETIC' not in minimized.read_text()
        report_page = context.new_page()
        report_page.set_content(minimized.read_text())
        assert report_page.locator('body').inner_text() == body
        if ENGINE == 'chromium':
            report_page.pdf(path=str(OUTPUT / 'synthetic-minimized-report.pdf'), prefer_css_page_size=True, print_background=True)
        report_page.close()
        checks.append('actual minimized report download matches reviewed document and excludes private notes/detailed clocks by default')
        tools.get_by_label('Include follow-up status and notes for this check.', exact=True).check()
        expect(tools.get_by_role('button', name='Download reviewed report (HTML)', exact=True)).to_have_count(0)
        tools.get_by_label('Include detailed recorded clock/break facts.', exact=True).check()
        tools.get_by_role('button', name='Review evidence report', exact=True).click()
        reviewed = tools.frame_locator('iframe')
        expect(reviewed.get_by_text('Correction confirmed by me', exact=True)).to_be_visible()
        detailed_body = reviewed.locator('body').inner_text()
        assert private_note in detailed_body and frozen_check['work'][0]['startUTC'] in detailed_body
        assert reviewed.locator('script').count() == 0
        with page.expect_download() as detailed_event:
            tools.get_by_role('button', name='Download reviewed report (HTML)', exact=True).click()
        detailed = OUTPUT / 'synthetic-detailed-report.html'
        detailed_event.value.save_as(detailed)
        assert '&lt;script&gt;not executable&lt;/script&gt;' in detailed.read_text()
        print_page = context.new_page()
        print_page.set_content(detailed.read_text())
        assert print_page.locator('body').inner_text() == detailed_body
        if ENGINE == 'chromium':
            print_page.pdf(path=str(OUTPUT / 'synthetic-detailed-report.pdf'), prefer_css_page_size=True, print_background=True)
        print_page.emulate_media(media='print')
        print_page.screenshot(path=str(OUTPUT / 'report-print-layout.png'), full_page=True)
        print_page.close()
        assert read_state(page)['periods'][0]['audits'][0] == frozen_check
        assert len(read_state(page)['resolutionEvents']) == 1
        checks.append('optional follow-up/work facts require renewed exact-report review, escape source text, preserve the original verdict and do not auto-mark shared')

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
        sender_before = read_state(page)
        source_profile = sender_before['profiles'][-1]
        page.get_by_role('button', name='Pay rules', exact=True).click()
        page.get_by_label('Rule draft title', exact=True).fill('SYNTHETIC crew rules')
        page.get_by_label('I have the right to share these rule parameters.', exact=True).check()
        page.get_by_role('button', name='Review rule file', exact=True).click()
        expect(page.locator('#template-export-preview')).to_contain_text('Omitted — enter your own')
        page.locator('#template-export-preview').scroll_into_view_if_needed()
        page.screenshot(path=str(OUTPUT / 'crew-export-preview.png'))
        with page.expect_download() as transfer_event:
            page.get_by_role('button', name='Download reviewed rule draft', exact=True).click()
        transfer = OUTPUT / 'synthetic-crew.linepayrules'
        transfer_event.value.save_as(transfer)
        draft = json.loads(transfer.read_text())
        assert draft['rules']['hourlyRate'] is None and draft['rules']['perDiem'] == {'configured': True, 'amount': None}
        assert source_profile['id'] not in transfer.read_text() and sender_before['periods'][0]['id'] not in transfer.read_text()
        assert read_state(page) == sender_before
        checks.append('actual reviewed crew-file download omits wage/allowance amounts and private profile/period identity by default')
        page.get_by_label('Include hourly wage and per-diem amounts in this file.', exact=True).check()
        expect(page.get_by_role('button', name='Download reviewed rule draft', exact=True)).to_have_count(0)
        assert not page.get_by_label('I have the right to share these rule parameters.', exact=True).is_checked()
        page.get_by_label('I have the right to share these rule parameters.', exact=True).check()
        page.get_by_role('button', name='Review rule file', exact=True).click()
        with page.expect_download() as explicit_event:
            page.get_by_role('button', name='Download reviewed rule draft', exact=True).click()
        explicit = OUTPUT / 'synthetic-crew-explicit-amounts.linepayrules'
        explicit_event.value.save_as(explicit)
        included = json.loads(explicit.read_text())
        assert included['rules']['hourlyRate'] == source_profile['hourlyRate'] and included['rules']['perDiem']['amount'] == source_profile['perDiemPerWorkDate']
        assert read_state(page) == sender_before
        checks.append('amount inclusion invalidates the previous file/rights preview and requires explicit re-review before another actual download')
        recipient_context = browser.new_context(accept_downloads=True)
        observe_context(recipient_context)
        recipient_context.on('request', lambda r: requests.append((r.url, r.method)))
        recipient = recipient_context.new_page()
        recipient.on('pageerror', lambda e: errors.append(str(e)))
        recipient.goto(origin + '/')
        expect(recipient.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        recipient.get_by_role('button', name='Pay rules', exact=True).click()
        ambiguous = OUTPUT / 'synthetic-ambiguous.linepayrules'
        ambiguous.write_text(transfer.read_text().replace('"hourlyRate": null','"hourlyRate": null, "hourly\\u0052ate": "99"'))
        assert r'\u0052' in ambiguous.read_text()
        recipient.get_by_label('Selected rule draft', exact=True).set_input_files(ambiguous)
        recipient.get_by_role('button', name='Inspect rule draft', exact=True).click()
        expect(recipient.locator('#status')).to_contain_text('Duplicate rule-draft fields')
        assert read_state(recipient)['profiles'] == [] and read_state(recipient)['templateOrigins'] == []
        checks.append('escaped duplicate monetary fields are refused before an ambiguous rule draft reaches adoption')
        recipient.get_by_label('Selected rule draft', exact=True).set_input_files(transfer)
        recipient.get_by_role('button', name='Inspect rule draft', exact=True).click()
        expect(recipient.locator('#template-import-preview')).to_contain_text('Inspected; no profile created')
        expect(recipient.get_by_label('Your confirmed hourly rate', exact=True)).to_have_value('')
        recipient.locator('#template-import-preview').scroll_into_view_if_needed()
        recipient.screenshot(path=str(OUTPUT / 'crew-recipient-review.png'))
        assert read_state(recipient)['profiles'] == [] and read_state(recipient)['templateOrigins'] == []
        recipient.get_by_label('Your confirmed hourly rate', exact=True).fill('75')
        recipient.get_by_label('I checked every listed rule and its applicability to my work, dates and classification.', exact=True).check()
        recipient.get_by_label('I confirmed the rate, currency, allowance choice and rounding policy.', exact=True).check()
        recipient.get_by_role('button', name='Save confirmed new profile', exact=True).click()
        expect(recipient.locator('#status')).to_contain_text('Review whether the configured allowance applies')
        assert read_state(recipient)['profiles'] == []
        checks.append('a second isolated browser inspects the actual file without creating a profile; omitted amounts/unknown allowance cannot silently become zero')
        recipient.get_by_label('Does this per-diem rule apply to your new profile?', exact=True).select_option('confirmedAmount')
        recipient.get_by_label('Your confirmed per-diem amount', exact=True).fill('120')
        recipient.get_by_label('I checked every listed rule and its applicability to my work, dates and classification.', exact=True).check()
        recipient.get_by_label('I confirmed the rate, currency, allowance choice and rounding policy.', exact=True).check()
        recipient.get_by_role('button', name='Save confirmed new profile', exact=True).click()
        accepted = read_state(recipient)
        assert len(accepted['profiles']) == 1 and len(accepted['templateOrigins']) == 1
        assert accepted['profiles'][0]['hourlyRate'] == '75' and accepted['profiles'][0]['perDiemPerWorkDate'] == '120'
        assert accepted['templateOrigins'][0]['packet'] == draft and accepted['templateOrigins'][0]['recipientHourlyRate'] == '75'
        assert accepted['periods'] == [] and accepted['benefitChecks'] == []
        recipient.get_by_role('button', name='Pay', exact=True).click()
        recipient.get_by_label('First work date', exact=True).fill('2026-10-01')
        recipient.get_by_label('Last work date (included)', exact=True).fill('2026-10-14')
        recipient.get_by_label('Payroll timezone', exact=True).fill('America/Chicago')
        recipient.get_by_role('button', name='Start period', exact=True).click()
        recipient.get_by_label('Start', exact=True).fill('2026-10-01T08:00')
        recipient.get_by_label('End', exact=True).fill('2026-10-01T09:00')
        recipient.get_by_role('button', name='Save work', exact=True).click()
        expect(recipient.locator('.answer')).to_have_text('USD 75.00')
        recipient.get_by_text('Calculation and saved rules', exact=True).click()
        expect(recipient.locator('main')).to_contain_text('Worker-provided rule draft: SYNTHETIC crew rules')
        assert read_state(page) == sender_before
        checks.append('recipient confirms own values into a new profile/period with retained draft provenance; sender histories never change or copy')
        recipient_before = read_state(recipient)
        recipient.get_by_role('button', name='Backup', exact=True).click()
        recipient.get_by_label('New backup password', exact=True).fill(PASSWORD)
        recipient.get_by_label('Repeat password', exact=True).fill(PASSWORD)
        with recipient.expect_download() as own_backup_event:
            recipient.get_by_role('button', name='Download encrypted backup', exact=True).click()
        own_backup = OUTPUT / 'synthetic-recipient.linepaybackup'
        own_backup_event.value.save_as(own_backup)
        recipient.get_by_role('button', name='Review removal', exact=True).click()
        recipient.get_by_role('button', name='Confirm remove all local records', exact=True).click()
        assert read_state(recipient)['templateOrigins'] == []
        recipient.get_by_label('Protected web backup', exact=True).set_input_files(own_backup)
        recipient.get_by_label('Backup password', exact=True).fill(PASSWORD)
        recipient.get_by_role('button', name='Unlock and inspect', exact=True).click()
        expect(recipient.locator('#restore-preview')).to_contain_text('records unchanged')
        assert read_state(recipient)['profiles'] == []
        recipient.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        recovered = read_state(recipient)
        for key in ['profiles', 'periods', 'benefitChecks', 'templateOrigins']:
            assert recovered[key] == recipient_before[key]
        recipient_context.close()
        checks.append('actual recipient encrypted backup/reset/inspect/replace preserves confirmed rule provenance and own monetary choices exactly')
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
        assert restored['resolutionEvents'] == baseline['resolutionEvents']
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
        # Both actual old schemas migrate only through explicit authenticated replacement.
        for old_version in [1, 2, 3]:
            legacy_context = browser.new_context(accept_downloads=True, service_workers='block')
            observe_context(legacy_context)
            legacy_context.on('request', lambda r: requests.append((r.url, r.method)))
            legacy_page = legacy_context.new_page()
            legacy_page.on('pageerror', lambda e: errors.append(str(e)))
            legacy_page.goto(origin + '/')
            expect(legacy_page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
            prior = json.loads((WEB / f'tests/fixtures/web-state-v{old_version}.json').read_text())
            protected = legacy_page.evaluate("""async ({state,password}) => {
              const {encryptBackup}=await import('./src/backup.mjs');
              return Array.from(await encryptBackup(new TextEncoder().encode(JSON.stringify({format:'com.streamentry.linepay.web.snapshot',version:1,state})),password));
            }""", {'state': prior, 'password': PASSWORD})
            prior_file = OUTPUT / f'synthetic-prior-v{old_version}.linepaybackup'
            prior_file.write_bytes(bytes(protected))
            legacy_page.get_by_role('button', name='Backup', exact=True).click()
            legacy_page.get_by_label('Protected web backup', exact=True).set_input_files(prior_file)
            legacy_page.get_by_label('Backup password', exact=True).fill(PASSWORD)
            legacy_page.get_by_role('button', name='Unlock and inspect', exact=True).click()
            expect(legacy_page.locator('#restore-preview')).to_contain_text('records unchanged')
            assert read_state(legacy_page)['periods'] == []
            legacy_page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
            migrated = read_state(legacy_page)
            assert migrated['version'] == 4 and migrated['resolutionEvents'] == []
            assert migrated['templateOrigins'] == prior.get('templateOrigins', [])
            assert migrated['benefitChecks'] == prior.get('benefitChecks', [])
            assert migrated['periods'] == prior['periods'] and migrated['profiles'] == prior['profiles']
            legacy_page.get_by_role('button', name='Pay', exact=True).click()
            expect(legacy_page.locator('.answer')).to_have_text('USD 400.00')
            if old_version == 2:
                retained = read_state(legacy_page)
                legacy_context.route('**/src/assessment.mjs', lambda route: route.abort('connectionreset'))
                legacy_page.reload()
                expect(legacy_page.get_by_role('heading', name='App code could not load', exact=True)).to_be_visible()
                expect(legacy_page.locator('#status')).to_contain_text('Stored records were not reset or replaced')
                legacy_page.screenshot(path=str(OUTPUT / 'asset-load-error.png'))
                legacy_context.unroute('**/src/assessment.mjs')
                legacy_page.get_by_role('button', name='Reload app', exact=True).click()
                expect(legacy_page.locator('.answer')).to_have_text('USD 400.00')
                assert read_state(legacy_page) == retained
                checks.append('a deliberately reset app-module request shows recoverable load error; real reload preserves existing restored wage/fund records exactly')
            legacy_context.close()
        checks.append('actual encrypted schema-v1/v2/v3 backups inspect without mutation then migrate with original wage/fund histories unchanged')
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
        page.get_by_role('button', name='Pay', exact=True).click()
        saved_check = page.locator(f'[data-paycheck-audit="{check_id}"]')
        if saved_check.get_attribute('open') is None:
            saved_check.locator(':scope > summary').click()
        offline_tools = page.locator(f'[data-audit-tools="{check_id}"]')
        offline_tools.get_by_role('button', name='Review evidence report', exact=True).click()
        offline_report = offline_tools.frame_locator('iframe')
        expect(offline_report.get_by_role('heading', name='LinePaycheck paycheck evidence report', exact=True)).to_be_visible()
        assert 'USD 1.00' in offline_report.locator('body').inner_text()
        assert 'PRIVATE SYNTHETIC' not in offline_report.locator('body').inner_text()
        offline_tools.locator('iframe').scroll_into_view_if_needed()
        page.screenshot(path=str(OUTPUT / 'offline-report-review.png'))
        checks.append('report review opens from preserved saved check while the real origin is stopped; private follow-up remains excluded')
        assert not errors, errors
        assert all((url.startswith(origin + '/') or url.startswith('blob:' + origin + '/')) and method == 'GET' for url, method in requests), requests
        checks.append('network traffic is same-origin asset GETs; report Blob views stay local and no pay data is sent')
        assert runtime_hash() == source_hash, 'Runtime source changed during browser verification'
        report = {'passed': True, 'runtimeSHA256': source_hash, 'browser': ENGINE, 'browserVersion': browser.version, 'checks': checks,
                  'scope': 'Synthetic local browser workflow. No deployment, actual OS Files delivery, native snapshot migration, installed-PWA/physical-device or App Store release proof.'}
        (OUTPUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
    except Exception as failure:
        captured = []
        for ci, active_context in enumerate(browser.contexts):
            for pi, active_page in enumerate(active_context.pages):
                label = f'failure-c{ci}-p{pi}'
                try:
                    active_page.screenshot(path=str(OUTPUT / (label + '.png')), full_page=True)
                    body = active_page.locator('body').inner_text()
                    (OUTPUT / (label + '.txt')).write_text(body)
                    captured.append({'context': ci, 'page': pi, 'url': active_page.url, 'body': body, 'readiness': active_page.evaluate('({document:document.readyState, resources:performance.getEntriesByType("resource").map(r=>({name:r.name,duration:r.duration,transferSize:r.transferSize}))})')})
                except Exception as capture_error:
                    captured.append({'context': ci, 'page': pi, 'captureError': str(capture_error)})
        (OUTPUT / 'failure.txt').write_text(json.dumps({'failure': str(failure), 'pageErrors': errors, 'consoleErrors': console_errors, 'responses': responses, 'failedRequests': failed_requests, 'contexts': captured}, indent=2))
        (OUTPUT / 'report.json').write_text(json.dumps({'passed': False, 'browser': ENGINE, 'browserVersion': browser.version, 'runtimeSHA256': source_hash, 'checks': checks, 'failure': str(failure)}, indent=2))
        raise
    finally:
        browser.close()
        server.shutdown()
        server.server_close()
