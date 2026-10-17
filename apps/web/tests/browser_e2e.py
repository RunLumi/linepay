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

def profile(page, rate, diem="80", threshold=None):
    page.get_by_role('button', name='Pay rules', exact=True).click()
    page.get_by_label('Hourly rate', exact=True).fill(rate)
    page.get_by_label('Per diem per worked local date', exact=True).fill(diem)
    if threshold is not None:
        page.get_by_label('Daily overtime after hours', exact=True).fill(threshold)
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
        page.get_by_role('button', name='Review pay period', exact=True).click()
        page.get_by_role('button', name='Start period', exact=True).click()
        page.get_by_label('Start', exact=True).fill('2026-10-01T08:00')
        page.get_by_label('End', exact=True).fill('2026-10-01T08:30')
        page.get_by_role('button', name='Save work', exact=True).click()
        expect(page.locator('.answer')).to_have_text('USD 10.00')
        checks.append('profile → explicit period/timezone → actual work → exact 19.99 half-hour cent')
        page.get_by_label('Confirmed paycheck gross', exact=True).fill('9.00')
        page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
        page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
        page.get_by_label('Reported first work date', exact=True).fill('2026-10-01')
        page.get_by_label('Reported last work date (included)', exact=True).fill('2026-10-14')
        page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
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
        recipient.get_by_role('button', name='Review pay period', exact=True).click()
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
        for key in ['profiles', 'periods', 'benefitChecks', 'templateOrigins', 'paycheckScopes', 'paycycleSchedules']:
            assert recovered[key] == recipient_before[key]
        recipient_context.close()
        checks.append('actual recipient encrypted backup/reset/inspect/replace preserves confirmed rule provenance and own monetary choices exactly')
        timeline_context = browser.new_context(accept_downloads=True)
        observe_context(timeline_context)
        timeline_context.on('request', lambda r: requests.append((r.url, r.method)))
        timeline_page = timeline_context.new_page()
        timeline_page.on('pageerror', lambda e: errors.append(str(e)))
        timeline_page.goto(origin + '/')
        expect(timeline_page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        profile(timeline_page, '50', '80', '8')
        timeline_page.get_by_label('First work date', exact=True).fill('2026-10-05')
        timeline_page.get_by_label('Last work date (included)', exact=True).fill('2026-10-18')
        timeline_page.get_by_label('Payroll timezone', exact=True).fill('America/Chicago')
        timeline_page.get_by_role('button', name='Review pay period', exact=True).click()
        timeline_page.get_by_role('button', name='Start period', exact=True).click()
        for day, finish in [('05', '16:00'), ('06', '18:00')]:
            timeline_page.get_by_label('Start', exact=True).fill(f'2026-10-{day}T08:00')
            timeline_page.get_by_label('End', exact=True).fill(f'2026-10-{day}T{finish}')
            timeline_page.get_by_role('button', name='Save work', exact=True).click()
        expect(timeline_page.locator('.answer')).to_have_text('USD 950.00')
        def save_timeline_check(gross):
            timeline_page.get_by_label('Confirmed paycheck gross', exact=True).fill(gross)
            timeline_page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
            timeline_page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
            timeline_page.get_by_label('Reported first work date', exact=True).fill('2026-10-05')
            timeline_page.get_by_label('Reported last work date (included)', exact=True).fill('2026-10-18')
            timeline_page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
            timeline_page.get_by_role('button', name='Review comparison', exact=True).click()
            timeline_page.get_by_role('button', name='Save this check', exact=True).click()
        save_timeline_check('950')
        baseline_audit = read_state(timeline_page)['periods'][0]['audits'][0]
        profile(timeline_page, '55', '90', '8')
        expect(timeline_page.locator('.answer')).to_have_text('USD 950.00')
        timeline_page.get_by_text('Effective-date rule plan', exact=True).click()
        timeline_page.get_by_role('button', name='Add effective change', exact=True).click()
        timeline_page.get_by_label('Effective payroll-local date', exact=True).fill('2026-10-06')
        source_id = read_state(timeline_page)['profiles'][-1]['id']
        timeline_page.get_by_label('Confirmed source profile', exact=True).select_option(source_id)
        timeline_page.get_by_label('I confirmed these complete rules and effective dates apply to this period.', exact=True).check()
        timeline_page.get_by_role('button', name='Review proposed rule plan', exact=True).click()
        expect(timeline_page.locator('.timeline-preview')).to_contain_text('USD 1005.00')
        assert read_state(timeline_page)['ruleTimelines'] == []
        timeline_page.locator('.timeline-preview').scroll_into_view_if_needed()
        timeline_page.screenshot(path=str(OUTPUT / 'effective-rule-plan-preview.png'))
        timeline_page.get_by_label('Effective payroll-local date', exact=True).fill('2026-10-07')
        expect(timeline_page.get_by_role('button', name='Save confirmed rule plan', exact=True)).to_have_count(0)
        assert not timeline_page.get_by_label('I confirmed these complete rules and effective dates apply to this period.', exact=True).is_checked()
        timeline_page.get_by_label('Effective payroll-local date', exact=True).fill('2026-10-06')
        timeline_page.get_by_label('I confirmed these complete rules and effective dates apply to this period.', exact=True).check()
        timeline_page.get_by_role('button', name='Review proposed rule plan', exact=True).click()
        timeline_page.get_by_role('button', name='Save confirmed rule plan', exact=True).click()
        expect(timeline_page.locator('.answer')).to_have_text('USD 1005.00')
        first_plan = read_state(timeline_page)['ruleTimelines'][0]
        assert read_state(timeline_page)['periods'][0]['audits'][0] == baseline_audit
        save_timeline_check('1005')
        dated_audit = read_state(timeline_page)['periods'][0]['audits'][1]
        assert dated_audit['calculation']['engine'] == 'linepay.web.configured-pay/2' and dated_audit['calculation']['ruleTimelineID'] == first_plan['id']
        checks.append('effective-date preview writes nothing; confirmed local-date rate/allowance plan yields 1005 and retains original 950 engine-v1 check')
        timeline_page.get_by_label('Effective payroll-local date', exact=True).fill('2026-10-07')
        timeline_page.get_by_label('I confirmed these complete rules and effective dates apply to this period.', exact=True).check()
        timeline_page.get_by_role('button', name='Review proposed rule plan', exact=True).click()
        timeline_page.get_by_role('button', name='Save confirmed rule plan', exact=True).click()
        expect(timeline_page.locator('.answer')).to_have_text('USD 950.00')
        assert read_state(timeline_page)['periods'][0]['audits'][1] == dated_audit
        saved_details = timeline_page.locator(f'[data-paycheck-audit="{dated_audit["id"]}"]')
        if saved_details.get_attribute('open') is None:
            saved_details.locator(':scope > summary').click()
        saved_tools = timeline_page.locator(f'[data-audit-tools="{dated_audit["id"]}"]')
        saved_tools.get_by_role('button', name='Review evidence report', exact=True).click()
        historical_report = saved_tools.frame_locator('iframe')
        expect(historical_report.get_by_role('heading', name='LinePaycheck paycheck evidence report', exact=True)).to_be_visible()
        assert 'USD 1005.00' in historical_report.locator('body').inner_text() and 'USD 55/hour' in historical_report.locator('body').inner_text()
        with timeline_page.expect_download() as dated_report_event:
            saved_tools.get_by_role('button', name='Download reviewed report (HTML)', exact=True).click()
        dated_report = OUTPUT / 'synthetic-effective-report.html'
        dated_report_event.value.save_as(dated_report)
        dated_html = dated_report.read_text()
        assert first_plan['id'] in dated_html and read_state(timeline_page)['ruleTimelines'][-1]['id'] not in dated_html
        assert 'USD 1005.00' in dated_html and '2026-10-06' in dated_html
        dated_page = timeline_context.new_page()
        dated_page.set_content(dated_html)
        assert dated_page.locator('body').inner_text() == historical_report.locator('body').inner_text()
        if ENGINE == 'chromium':
            dated_page.pdf(path=str(OUTPUT / 'synthetic-effective-report.pdf'), prefer_css_page_size=True, print_background=True)
        dated_page.screenshot(path=str(OUTPUT / 'effective-report-review.png'), full_page=True)
        dated_page.close()
        checks.append('actual historical dated-report download retains the original plan/date/1005 amount and excludes the newer ledger plan')

        timeline_page.get_by_role('button', name='Close this period', exact=True).click()
        timeline_page.get_by_role('button', name='Confirm close period', exact=True).click()
        assert read_state(timeline_page)['periods'][0]['closedCalculation']['wages'] == '950.00'
        expect(timeline_page.get_by_role('button', name='Add effective change', exact=True)).to_have_count(0)
        timeline_before = read_state(timeline_page)
        timeline_page.get_by_role('button', name='Backup', exact=True).click()
        timeline_page.get_by_label('New backup password', exact=True).fill(PASSWORD)
        timeline_page.get_by_label('Repeat password', exact=True).fill(PASSWORD)
        with timeline_page.expect_download() as timeline_backup_event:
            timeline_page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        timeline_backup = OUTPUT / 'synthetic-rule-timeline.linepaybackup'
        timeline_backup_event.value.save_as(timeline_backup)
        timeline_page.get_by_role('button', name='Review removal', exact=True).click()
        timeline_page.get_by_role('button', name='Confirm remove all local records', exact=True).click()
        assert read_state(timeline_page)['ruleTimelines'] == []
        timeline_page.get_by_label('Protected web backup', exact=True).set_input_files(timeline_backup)
        timeline_page.get_by_label('Backup password', exact=True).fill(PASSWORD)
        timeline_page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        assert read_state(timeline_page)['periods'] == []
        timeline_page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        timeline_after = read_state(timeline_page)
        for key in ['profiles','periods','ruleTimelines','benefitChecks','templateOrigins','resolutionEvents','paycheckScopes','paycycleSchedules']:
            assert timeline_after[key] == timeline_before[key]
        timeline_page.get_by_role('button', name='Pay', exact=True).click()
        expect(timeline_page.locator('.answer')).to_have_text('USD 950.00')
        timeline_page.emulate_media(color_scheme='dark', reduced_motion='reduce')
        timeline_page.set_viewport_size({'width': 390, 'height': 844})
        timeline_page.evaluate("document.documentElement.style.fontSize='26px'")
        assert timeline_page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        timeline_page.evaluate('scrollTo(0,0)')
        timeline_page.screenshot(path=str(OUTPUT / 'effective-rule-history.png'))
        timeline_context.close()
        checks.append('a second explicit plan/close changes current estimate only; historical 1005 report and both rule plans survive actual encrypted reset/recovery')
        calendar_context = browser.new_context(accept_downloads=True, timezone_id='Asia/Tokyo')
        observe_context(calendar_context)
        calendar_context.on('request', lambda r: requests.append((r.url, r.method)))
        calendar_page = calendar_context.new_page()
        calendar_page.on('pageerror', lambda e: errors.append(str(e)))
        calendar_page.goto(origin + '/')
        expect(calendar_page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        profile(calendar_page, '50')
        calendar_page.get_by_label('Paycycle', exact=True).select_option('weekly')
        calendar_page.get_by_label('First work date', exact=True).fill('2026-03-02')
        calendar_page.get_by_label('Payroll timezone', exact=True).fill('America/Los_Angeles')
        expect(calendar_page.get_by_label('Last work date (included)', exact=True)).to_have_value('2026-03-08')
        calendar_page.get_by_role('button', name='Review pay period', exact=True).click()
        expect(calendar_page.locator('.period-preview')).to_contain_text('2026-03-09T07:00:00Z')
        assert read_state(calendar_page)['periods'] == []
        calendar_page.get_by_label('First work date', exact=True).fill('2026-03-03')
        expect(calendar_page.get_by_role('button', name='Start period', exact=True)).to_have_count(0)
        calendar_page.get_by_label('First work date', exact=True).fill('2026-03-02')
        calendar_page.get_by_role('button', name='Review pay period', exact=True).click()
        calendar_page.screenshot(path=str(OUTPUT / 'calendar-week-preview.png'), full_page=True)
        calendar_page.get_by_role('button', name='Start period', exact=True).click()
        assert read_state(calendar_page)['paycycleSchedules'][0]['window']['elapsedSeconds'] == 167 * 3600
        calendar_page.get_by_label('Start', exact=True).fill('2026-03-03T08:00')
        calendar_page.get_by_label('End', exact=True).fill('2026-03-03T16:00')
        calendar_page.get_by_role('button', name='Save work', exact=True).click()
        expect(calendar_page.locator('.answer')).to_have_text('USD 400.00')
        checks.append('weekly calendar preview writes nothing, material edits invalidate it, and fixed LA zone retains a 167-hour DST week on a Tokyo device')
        def calendar_review(start, end, confirmed):
            calendar_page.get_by_label('Confirmed paycheck gross', exact=True).fill('375')
            calendar_page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
            calendar_page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
            if start is not None:
                calendar_page.get_by_label('Reported first work date', exact=True).fill(start)
                calendar_page.get_by_label('Reported last work date (included)', exact=True).fill(end)
            if confirmed:
                calendar_page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
            calendar_page.get_by_role('button', name='Review comparison', exact=True).click()
        calendar_review('2026-03-09', '2026-03-15', True)
        expect(calendar_page.locator('#audit-preview')).to_contain_text('Not comparable')
        assert read_state(calendar_page)['periods'][0]['audits'] == []
        calendar_page.get_by_role('button', name='Save this check', exact=True).click()
        mismatched = read_state(calendar_page)['periods'][0]['audits'][0]
        assert mismatched['assessment']['periodMatch'] == 'differentPeriod' and mismatched['assessment']['gross'] is None and mismatched['assessment']['difference'] is None
        mismatch_tools = calendar_page.locator(f'[data-audit-tools="{mismatched["id"]}"]')
        mismatch_tools.get_by_role('button', name='Review evidence report', exact=True).click()
        mismatch_report = mismatch_tools.frame_locator('iframe')
        expect(mismatch_report.get_by_role('heading', name='LinePaycheck paycheck evidence report', exact=True)).to_be_visible()
        mismatch_body = mismatch_report.locator('body').inner_text()
        assert '2026-03-09 through 2026-03-15' in mismatch_body and 'Different work period / context' in mismatch_body and 'USD 25.00' not in mismatch_body
        calendar_page.screenshot(path=str(OUTPUT / 'mismatched-period-review.png'), full_page=True)
        checks.append('source dates from another week cannot produce a shortfall; recorded facts/report retain mismatch and unknown expected comparison')
        calendar_review(None, None, False)
        expect(calendar_page.locator('#audit-preview')).to_contain_text('Not comparable')
        calendar_page.get_by_role('button', name='Save this check', exact=True).click()
        assert read_state(calendar_page)['periods'][0]['audits'][1]['assessment']['periodMatch'] == 'unconfirmedPeriod'
        calendar_review('2026-03-02', '2026-03-08', True)
        expect(calendar_page.locator('#audit-preview')).to_contain_text('Possible shortfall')
        calendar_page.get_by_label('Reported last work date (included)', exact=True).fill('2026-03-07')
        expect(calendar_page.get_by_role('button', name='Save this check', exact=True)).to_have_count(0)
        assert not calendar_page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).is_checked()
        calendar_page.get_by_label('Reported last work date (included)', exact=True).fill('2026-03-08')
        calendar_page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
        calendar_page.get_by_role('button', name='Review comparison', exact=True).click()
        calendar_page.get_by_role('button', name='Save this check', exact=True).click()
        matched = read_state(calendar_page)['periods'][0]['audits'][2]
        assert matched['assessment']['periodMatch'] == 'confirmedSamePeriod' and matched['assessment']['difference'] == '25.00'
        checks.append('unknown dates remain unconfirmed/noncomparable; only explicitly matching source dates allow a directional amount, and later date edits clear confirmation')
        calendar_page.get_by_role('button', name='Close this period', exact=True).click()
        calendar_page.get_by_role('button', name='Confirm close period', exact=True).click()
        calendar_page.get_by_label('Paycycle', exact=True).select_option('biweekly')
        calendar_page.get_by_label('First work date', exact=True).fill('2026-10-26')
        calendar_page.get_by_label('Payroll timezone', exact=True).fill('America/Los_Angeles')
        calendar_page.get_by_role('button', name='Review pay period', exact=True).click()
        calendar_page.get_by_role('button', name='Start period', exact=True).click()
        assert read_state(calendar_page)['paycycleSchedules'][-1]['window']['elapsedSeconds'] == 337 * 3600
        calendar_page.get_by_role('button', name='Discard empty period', exact=True).click()
        calendar_page.get_by_role('button', name='Confirm discard empty period', exact=True).click()
        calendar_page.get_by_label('Paycycle', exact=True).select_option('semimonthly')
        calendar_page.get_by_label('First work date', exact=True).fill('2028-02-15')
        calendar_page.get_by_label('Payroll timezone', exact=True).fill('UTC')
        calendar_page.get_by_role('button', name='Review pay period', exact=True).click()
        expect(calendar_page.locator('#status')).to_contain_text('start on the 1st or 16th')
        assert len(read_state(calendar_page)['periods']) == 1
        calendar_page.get_by_label('First work date', exact=True).fill('2028-02-16')
        expect(calendar_page.get_by_label('Last work date (included)', exact=True)).to_have_value('2028-02-29')
        calendar_page.get_by_role('button', name='Review pay period', exact=True).click()
        calendar_page.get_by_role('button', name='Start period', exact=True).click()
        assert read_state(calendar_page)['paycycleSchedules'][-1]['window']['endExclusiveUTC'] == '2028-03-01T00:00:00Z'
        calendar_page.get_by_role('button', name='Discard empty period', exact=True).click()
        calendar_page.get_by_role('button', name='Confirm discard empty period', exact=True).click()
        assert len(read_state(calendar_page)['paycycleSchedules']) == 1
        checks.append('biweekly fall boundary and leap-February semimonthly boundary are calendar-based; invalid cutoffs never create records and explicit empty discard removes only owned metadata')
        calendar_before = read_state(calendar_page)
        calendar_page.get_by_role('button', name='Backup', exact=True).click()
        calendar_page.get_by_label('New backup password', exact=True).fill(PASSWORD)
        calendar_page.get_by_label('Repeat password', exact=True).fill(PASSWORD)
        with calendar_page.expect_download() as calendar_backup_event:
            calendar_page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        calendar_backup = OUTPUT / 'synthetic-period-scope.linepaybackup'
        calendar_backup_event.value.save_as(calendar_backup)
        calendar_page.get_by_role('button', name='Review removal', exact=True).click()
        calendar_page.get_by_role('button', name='Confirm remove all local records', exact=True).click()
        assert read_state(calendar_page)['paycheckScopes'] == [] and read_state(calendar_page)['paycycleSchedules'] == []
        calendar_page.get_by_label('Protected web backup', exact=True).set_input_files(calendar_backup)
        calendar_page.get_by_label('Backup password', exact=True).fill(PASSWORD)
        calendar_page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        assert read_state(calendar_page)['periods'] == []
        calendar_page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        calendar_after = read_state(calendar_page)
        for key in ['profiles','periods','benefitChecks','templateOrigins','resolutionEvents','ruleTimelines','paycycleSchedules','paycheckScopes']:
            assert calendar_after[key] == calendar_before[key]
        calendar_context.close()
        checks.append('actual encrypted reset/inspect/replace retains all three source-period reviews and fixed DST calendar metadata without inventing source dates')
        weekly_context = browser.new_context(accept_downloads=True, timezone_id='Asia/Tokyo')
        observe_context(weekly_context)
        weekly_context.on('request', lambda r: requests.append((r.url, r.method)))
        weekly_page = weekly_context.new_page()
        weekly_page.on('pageerror', lambda e: errors.append(str(e)))
        weekly_page.goto(origin + '/')
        expect(weekly_page.get_by_role('heading', name='Your work. Your expected pay.')).to_be_visible()
        profile(weekly_page, '50', diem='')
        weekly_page.get_by_label('First work date', exact=True).fill('2026-09-07')
        weekly_page.get_by_label('Last work date (included)', exact=True).fill('2026-09-13')
        weekly_page.get_by_label('Payroll timezone', exact=True).fill('UTC')
        weekly_page.get_by_role('button', name='Review pay period', exact=True).click()
        weekly_page.get_by_role('button', name='Start period', exact=True).click()
        for day in range(7,13):
            weekly_page.locator('#work-form [name=start]').fill(f'2026-09-{day:02d}T08:00')
            weekly_page.locator('#work-form [name=end]').fill(f'2026-09-{day:02d}T16:00')
            weekly_page.get_by_role('button', name='Save work', exact=True).click()
            expect(weekly_page.locator('.answer')).to_have_text(f'USD {(day-6)*400}.00')
        def weekly_paycheck():
            weekly_page.get_by_label('Confirmed paycheck gross', exact=True).fill('2400')
            weekly_page.get_by_label('What does gross include?', exact=True).select_option('wagesOnly')
            weekly_page.get_by_label('All work for this paycheck period is recorded.', exact=True).check()
            weekly_page.get_by_label('Reported first work date', exact=True).fill('2026-09-07')
            weekly_page.get_by_label('Reported last work date (included)', exact=True).fill('2026-09-13')
            weekly_page.get_by_label('I confirmed these work-period dates and timezone against the source.', exact=True).check()
            weekly_page.get_by_role('button', name='Review comparison', exact=True).click()
        weekly_paycheck()
        weekly_page.get_by_role('button', name='Save this check', exact=True).click()
        old_weekly_audit = read_state(weekly_page)['periods'][0]['audits'][0]
        weekly_page.get_by_role('button', name='Workweeks', exact=True).click()
        wf = weekly_page.locator('#weekly-form')
        wf.locator('[name=weekly-start]').fill('2026-09-07T00:00:00Z')
        wf.locator('[name=weekly-zone]').fill('UTC')
        wf.locator('[name=weekly-applicability]').select_option('coveredNonexemptHourly')
        wf.locator('[name=weekly-period]').check()
        wf.locator('[name=weekly-base]').fill('2400')
        def confirm_weekly():
            for name in ['weekly-boundary','weekly-employer','weekly-complete','weekly-payments-confirmed']:
                wf.locator(f'[name={name}]').check()
        confirm_weekly()
        weekly_page.get_by_role('button', name='Review complete workweek', exact=True).click()
        expect(weekly_page.locator('#weekly-preview')).to_contain_text('USD 2600.00')
        assert read_state(weekly_page)['weeklyReviews'] == []
        wf.locator('[name=weekly-base]').fill('2401')
        assert not wf.locator('[name=weekly-boundary]').is_checked()
        assert weekly_page.locator('#weekly-save').count() == 0
        wf.locator('[name=weekly-base]').fill('2400')
        weekly_page.locator('#weekly-add-payment').click()
        payment = weekly_page.locator('[data-weekly-payment]')
        payment.locator('[name=payment-amount]').fill('240')
        payment.locator('[name=payment-kind]').select_option('extraPremium')
        payment.locator('[name=payment-credit]').select_option('unknown')
        confirm_weekly()
        weekly_page.get_by_role('button', name='Review complete workweek', exact=True).click()
        expect(weekly_page.locator('#status')).to_contain_text('Unknown premium treatment')
        assert read_state(weekly_page)['weeklyReviews'] == []
        payment.locator('[name=payment-credit]').select_option('ineligible')
        wf.locator('[name=weekly-reference]').fill('PRIVATE SYNTHETIC weekly source <script>plain text</script>')
        confirm_weekly()
        weekly_page.get_by_role('button', name='Review complete workweek', exact=True).click()
        expect(weekly_page.locator('#weekly-preview')).to_contain_text('USD 2860.00')
        weekly_page.locator('#weekly-preview').screenshot(path=str(OUTPUT / 'weekly-review-preview.png'))
        payment.get_by_role('button', name='Remove payment', exact=True).click()
        assert weekly_page.locator('#weekly-save').count() == 0
        assert not wf.locator('[name=weekly-payments-confirmed]').is_checked()
        assert read_state(weekly_page)['weeklyReviews'] == []
        weekly_page.locator('#weekly-add-payment').click()
        payment = weekly_page.locator('[data-weekly-payment]')
        payment.locator('[name=payment-amount]').fill('240')
        payment.locator('[name=payment-kind]').select_option('extraPremium')
        payment.locator('[name=payment-credit]').select_option('ineligible')
        confirm_weekly()
        weekly_page.get_by_role('button', name='Review complete workweek', exact=True).click()
        expect(weekly_page.locator('#weekly-preview')).to_contain_text('USD 2860.00')
        weekly_page.locator('#weekly-save').click()
        expect(weekly_page.locator('.weekly-saved-result')).to_contain_text('USD 2860.00')
        saved_weekly = read_state(weekly_page)['weeklyReviews'][0]
        assert saved_weekly['result']['qualifyingSeconds'] == '172800'
        assert saved_weekly['result']['endExclusiveUTC'] == '2026-09-14T00:00:00Z'
        checks.append('weekly preview writes nothing, material edits clear confirmation, unknown premium refuses, and confirmed noncreditable work premium gives2860 from48h/2640 remuneration')
        weekly_page.get_by_role('button', name='Pay', exact=True).click()
        expect(weekly_page.locator('.answer')).to_have_text('USD 2400.00')
        assert read_state(weekly_page)['periods'][0]['audits'][0] == old_weekly_audit
        expect(weekly_page.locator(f'[data-paycheck-audit="{old_weekly_audit["id"]}"]')).to_contain_text('earlier work/rule/review context')
        weekly_paycheck()
        expect(weekly_page.locator('#audit-preview')).to_contain_text('Needs review')
        weekly_page.get_by_role('button', name='Save this check', exact=True).click()
        recorded = read_state(weekly_page)
        assert recorded['periods'][0]['audits'][-1]['assessment']['weeklyReviewReferences'] == [saved_weekly['id']]
        assert recorded['periods'][0]['audits'][-1]['facts']['weeklyReviewPending'] is False
        assert recorded['periods'][0]['audits'][0] == old_weekly_audit
        checks.append('retained weekly evidence is separate from Pay and automatically keeps new paycheck review open, while original pre-evidence comparison remains frozen')
        weekly_page.locator('[data-remove]').first.click()
        weekly_page.get_by_role('button', name='Confirm removal', exact=True).click()
        expect(weekly_page.locator('.answer')).to_have_text('USD 2000.00')
        assert read_state(weekly_page)['weeklyReviews'] == [saved_weekly]
        weekly_page.get_by_role('button', name='Workweeks', exact=True).click()
        weekly_page.set_viewport_size({'width':320,'height':900})
        weekly_page.emulate_media(color_scheme='dark', reduced_motion='reduce')
        weekly_page.evaluate("document.documentElement.style.fontSize='26px'")
        weekly_page.screenshot(path=str(OUTPUT / 'weekly-history-dark-large.png'), full_page=True)
        (OUTPUT / 'weekly-overflow.json').write_text(json.dumps(weekly_page.evaluate("() => [...document.querySelectorAll('main *')].filter(e=>e.getBoundingClientRect().right>innerWidth).map(e=>({tag:e.tagName,name:e.getAttribute('name'),text:e.textContent.slice(0,90),width:e.getBoundingClientRect().width,min:getComputedStyle(e).minWidth})).slice(0,30)"),indent=2))
        assert weekly_page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        weekly_page.screenshot(path=str(OUTPUT / 'weekly-history-dark-large.png'), full_page=True)
        weekly_page.get_by_role('button', name='Backup', exact=True).click()
        weekly_page.get_by_label('New backup password', exact=True).fill(PASSWORD)
        weekly_page.get_by_label('Repeat password', exact=True).fill(PASSWORD)
        with weekly_page.expect_download() as weekly_event:
            weekly_page.get_by_role('button', name='Download encrypted backup', exact=True).click()
        weekly_backup = OUTPUT / 'synthetic-weekly.linepaybackup'
        weekly_event.value.save_as(weekly_backup)
        weekly_before = read_state(weekly_page)
        weekly_page.get_by_role('button', name='Review removal', exact=True).click()
        weekly_page.get_by_role('button', name='Confirm remove all local records', exact=True).click()
        assert read_state(weekly_page)['weeklyReviews'] == []
        weekly_page.get_by_label('Protected web backup', exact=True).set_input_files(weekly_backup)
        weekly_page.get_by_label('Backup password', exact=True).fill(PASSWORD)
        weekly_page.get_by_role('button', name='Unlock and inspect', exact=True).click()
        assert read_state(weekly_page)['weeklyReviews'] == []
        weekly_page.get_by_role('button', name='Replace with inspected backup', exact=True).click()
        weekly_after = read_state(weekly_page)
        for key in ['periods','profiles','weeklyReviews','paycheckScopes']:
            assert weekly_after[key] == weekly_before[key]
        weekly_page.evaluate('() => navigator.serviceWorker.ready.then(() => true)')
        weekly_page.reload()
        weekly_page.wait_for_function('() => !!navigator.serviceWorker.controller')
        checks.append('later ledger removal leaves saved48h weekly evidence unchanged; actual encrypted export/reset/inspect/replace preserves original inputs, classifications and paycheck context')
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
        assert restored['paycheckScopes'] == baseline['paycheckScopes'] and restored['paycycleSchedules'] == baseline['paycycleSchedules']
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
        for old_version in [1, 2, 3, 4, 5, 6]:
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
            assert migrated['version'] == 7 and migrated['weeklyReviews'] == []
            assert migrated['paycheckScopes'] == prior.get('paycheckScopes', []) and migrated['paycycleSchedules'] == prior.get('paycycleSchedules', [])
            assert migrated['ruleTimelines'] == prior.get('ruleTimelines', [])
            assert migrated['resolutionEvents'] == prior.get('resolutionEvents', [])
            assert migrated['templateOrigins'] == prior.get('templateOrigins', [])
            assert migrated['benefitChecks'] == prior.get('benefitChecks', [])
            assert migrated['periods'] == prior['periods'] and migrated['profiles'] == prior['profiles']
            legacy_page.get_by_role('button', name='History', exact=True).click()
            legacy_page.locator(f'[data-period="{prior["periods"][0]["id"]}"]').click()
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
        checks.append('actual encrypted schema-v1/v2/v3/v4/v5/v6 backups inspect without mutation then migrate with original wage/fund histories unchanged')
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
        weekly_response = weekly_page.reload()
        assert weekly_response.from_service_worker
        expect(weekly_page.locator('.answer')).to_have_text('USD 2000.00')
        weekly_page.get_by_role('button', name='Workweeks', exact=True).click()
        expect(weekly_page.locator('.weekly-saved-result')).to_contain_text('USD 2860.00')
        assert read_state(weekly_page)['weeklyReviews'] == [saved_weekly]
        weekly_context.close()
        checks.append('stopped-origin reload serves the real cached weekly modules and preserves saved weekly cash/clock facts without a backend')
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
