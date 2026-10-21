"""Real local browser replacement/roundtrip; canonical synthetic Android pending receipt."""
import functools
import hashlib
import json
import os
from pathlib import Path
import threading
import subprocess
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright, expect
ROOT=Path(__file__).resolve().parents[3]
WEB=ROOT/'apps/web'
FIXTURE=Path(os.environ.get('PORTABLE_FIXTURE',ROOT/'shared/contracts/portable-state/fixtures/common-weekly-pending.json'))
OUTPUT=ROOT/'.build/web-portable-e2e'
OUTPUT.mkdir(parents=True,exist_ok=True)
PHRASE='Synthetic portable password 2026'
INPUT_BACKUP=os.environ.get('PORTABLE_INPUT_BACKUP')
INPUT_PHRASE=os.environ.get('PORTABLE_INPUT_PASSWORD',PHRASE)
CONTRACT=Path(os.environ.get('PORTABLE_CONTRACT_ROOT',ROOT/'shared/contracts/portable-state'))
def tree_hash():
    digest=hashlib.sha256()
    for file in sorted(WEB.rglob('*')):
        if file.is_file() and '__pycache__' not in file.parts:
            digest.update(str(file.relative_to(WEB)).encode());digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()
source_tree_hash=tree_hash()
source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
schema_hash=hashlib.sha256((CONTRACT/'schema-v1.json').read_bytes()).hexdigest()
def runtime_hash():
    digest=hashlib.sha256()
    for file in sorted(WEB.rglob('*')):
        if file.is_file() and 'tests' not in file.relative_to(WEB).parts and file.suffix in {'.mjs','.js','.html','.css','.png','.svg','.webmanifest'}:
            digest.update(str(file.relative_to(WEB)).encode());digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()
source_hash=runtime_hash()
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
class LocalServer(ThreadingHTTPServer):
    request_queue_size=64
server=LocalServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(WEB)))
threading.Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}'
fixture=json.loads(FIXTURE.read_text())
current=next((period for period in fixture['periods'] if period['isCurrent'] is True),fixture['periods'][0])
expected=fixture['paycheckReceipts'][0]['assessment']['expectedGross']
expected_text=f"{expected['currency']} {float(expected['amount']):.2f}"
def patched(document,operations):
    result=json.loads(json.dumps(document))
    for operation in operations:
        parts=[key.replace('~1','/').replace('~0','~') for key in operation['path'][1:].split('/')]
        target=result
        for key in parts[:-1]:target=target[int(key)] if isinstance(target,list) else target[key]
        key=int(parts[-1]) if isinstance(target,list) else parts[-1]
        if operation['op']=='remove':del target[key]
        else:target[key]=operation['value']
    return result
with sync_playwright() as pw:
    engine=os.environ.get('BROWSER','chromium')
    options={'headless':True}
    if engine=='chromium' and os.environ.get('CHROMIUM_EXECUTABLE'):
        options['executable_path']=os.environ['CHROMIUM_EXECUTABLE']
    (OUTPUT/f'{engine}-report.json').unlink(missing_ok=True)
    browser=getattr(pw,engine).launch(**options)
    context=browser.new_context(viewport={'width':390,'height':844},accept_downloads=True)
    errors=[]
    page=context.new_page()
    page.on('pageerror',lambda error: errors.append(str(error)))
    def read():
        return page.evaluate("async()=>await(await(await import('./src/state.mjs')).openStore()).read()")
    def seal(document,path):
        encoded=page.evaluate("""async ([document,password])=>Array.from(await(await import('./src/backup.mjs')).encryptBackup(new TextEncoder().encode(JSON.stringify(document)),password))""",[document,PHRASE])
        path.write_bytes(bytes(encoded))
    def activity():
        return page.evaluate("async()=>{const store=await(await import('./src/local-activity.mjs')).openLocalActivityStore();try{return await store.read();}finally{store.close();}}")
    def inspect(path,password=PHRASE):
        page.get_by_label('Protected web backup',exact=True).set_input_files(path)
        page.get_by_label('Backup password',exact=True).fill(password)
        page.get_by_role('button',name='Unlock and inspect',exact=True).click()
    try:
        page.goto(origin)
        expect(page.get_by_role('heading',name='Is Your Paycheck Correct?',exact=True)).to_be_visible()
        page.get_by_role('button',name='Pay rules',exact=True).click()
        page.get_by_label('Hourly rate',exact=True).fill('51.25')
        page.get_by_role('button',name='Backup',exact=True).click()
        expect(page.get_by_role('alertdialog',name='Unsaved financial input')).to_be_visible()
        page.get_by_role('button',name='Cancel; keep editing',exact=True).click()
        expect(page.get_by_label('Hourly rate',exact=True)).to_have_value('51.25')
        page.get_by_role('button',name='Backup',exact=True).click()
        page.get_by_role('button',name='Discard input and continue',exact=True).click()
        expect(page.get_by_role('heading',name='Keep a copy you control')).to_be_visible()
        page.get_by_role('button',name='Backup',exact=True).click()
        baseline=read()
        protected=Path(INPUT_BACKUP) if INPUT_BACKUP else OUTPUT/f'{engine}-synthetic-android.linepaybackup'
        if not INPUT_BACKUP:seal(fixture,protected)
        inspect(protected,'wrong synthetic password')
        expect(page.locator('#status')).to_contain_text('Could not unlock')
        assert read()==baseline
        inspect(protected,INPUT_PHRASE)
        expect(page.get_by_role('heading',name='Backup inspected; records unchanged')).to_be_visible()
        assert read()==baseline
        page.get_by_role('button',name='Replace with inspected backup',exact=True).click()
        expect(page.locator('#status')).to_contain_text('Inspected backup restored')
        imported=read()
        assert len(imported['profiles'])==len(fixture['profiles'])
        assert sum(len(p['work']) for p in imported['periods'])>0
        assert imported['portableArchive']['document']==fixture
        page.get_by_role('button',name='Pay',exact=True).click()
        expect(page.get_by_role('heading',name='Confirm a new browser configuration')).to_be_visible()
        assert page.locator('.answer').count()==0
        assert page.locator('#audit-form').count()==0
        page.screenshot(path=str(OUTPUT/f'{engine}-independent-confirmation.png'),full_page=True)
        page.get_by_role('button',name='History',exact=True).click()
        receipt=page.locator('[data-portable-receipt]').first
        receipt.locator('summary').first.click()
        expect(receipt).to_contain_text('Needs review')
        expect(receipt).to_contain_text('complete-workweek review remains pending')
        assert fixture['paycheckReceipts'][0]['assessment']['verdict']=='needsReview'
        assert fixture['paycheckReceipts'][0]['reviewFacts']['weeklyReviewPending'] is True
        page.screenshot(path=str(OUTPUT/f'{engine}-pending-receipt.png'),full_page=True)
        page.get_by_role('button',name='Backup',exact=True).click()
        page.get_by_label('Backup format',exact=True).select_option('portable')
        page.get_by_label('New backup password',exact=True).fill(PHRASE)
        page.get_by_label('Repeat password',exact=True).fill(PHRASE)
        with page.expect_download() as download:
            page.get_by_role('button',name='Download encrypted backup',exact=True).click()
        output=OUTPUT/f'{engine}-roundtrip.linepaybackup'
        download.value.save_as(output)
        roundtrip=page.evaluate("""async ([bytes,password])=>JSON.parse(new TextDecoder().decode(await(await import('./src/backup.mjs')).decryptBackup(new Uint8Array(bytes),password)))""",[list(output.read_bytes()),PHRASE])
        assert {key:value for key,value in roundtrip.items() if key not in {'source','exportedAtEpochSeconds'}}=={key:value for key,value in fixture.items() if key not in {'source','exportedAtEpochSeconds'}}
        assert roundtrip['source']['client']=='web'
        page.get_by_role('button',name='Pay',exact=True).click()
        page.get_by_label('New rounding decimal places',exact=True).select_option('2')
        page.get_by_label('New rounding method',exact=True).select_option('halfUp')
        page.get_by_label('I independently confirmed these rounding settings for a new browser rule snapshot and an editable copy of this work period.',exact=True).check()
        page.get_by_label('Use this new browser configuration for future periods.',exact=True).check()
        page.get_by_role('button',name='Confirm new browser rule snapshot',exact=True).click()
        expect(page.locator('.answer')).to_have_text(expected_text)
        adopted=read()
        assert len(adopted['portableArchive']['activationConfirmations'])==1
        assert adopted['portableArchive']['document']==fixture
        page.get_by_label('Confirmed paycheck gross',exact=True).fill(expected['amount'])
        page.get_by_label('What does gross include?',exact=True).select_option('wagesOnly')
        page.get_by_label('All work for this paycheck period is recorded.',exact=True).check()
        page.get_by_label('Reported first work date',exact=True).fill(current['calendarWindow']['startDate'])
        page.get_by_label('Reported last work date (included)',exact=True).fill(current['calendarWindow']['endDateInclusive'])
        page.get_by_label('I confirmed these work-period dates and timezone against the source.',exact=True).check()
        page.get_by_role('button',name='Review comparison',exact=True).click()
        expect(page.locator('#audit-preview')).to_contain_text('Needs review')
        page.get_by_role('button',name='Save this check',exact=True).click()
        saved=read()['periods'][-1]['audits'][-1]
        assert saved['facts']['weeklyReviewPending'] is True
        missing_rules=any(field in {'regularSchedule','dailyOvertimeTiers','outsideScheduleMultiplier','weekdayPremiums','datePremiums','calloutMinimumHours','perDiemPerWorkDate','weeklyOvertime','rounding'} for rule in fixture['ruleSnapshots'] for field in rule['fieldsNotRecorded'])
        if missing_rules:assert saved['facts']['unsupportedRules'] is True
        assert saved['assessment']['verdict']=='needsReview'
        page.screenshot(path=str(OUTPUT/f'{engine}-adopted-needs-review.png'),full_page=True)
        page.get_by_role('button',name='Backup',exact=True).click()
        page.get_by_label('Backup format',exact=True).select_option('portable')
        page.get_by_label('New backup password',exact=True).fill(PHRASE)
        page.get_by_label('Repeat password',exact=True).fill(PHRASE)
        with page.expect_download() as download:
            page.get_by_role('button',name='Download encrypted backup',exact=True).click()
        combined_file=OUTPUT/f'{engine}-combined.linepaybackup';download.value.save_as(combined_file)
        combined=page.evaluate("""async ([bytes,password])=>JSON.parse(new TextDecoder().decode(await(await import('./src/backup.mjs')).decryptBackup(new Uint8Array(bytes),password)))""",[list(combined_file.read_bytes()),PHRASE])
        assert combined['paycheckReceipts'][:len(fixture['paycheckReceipts'])]==fixture['paycheckReceipts']
        assert len(combined['adoptions'])==1 and len(combined['paycheckReceipts'])==2
        inspect(combined_file)
        expect(page.get_by_role('heading',name='Backup inspected; records unchanged')).to_be_visible()
        page.get_by_role('button',name='Replace with inspected backup',exact=True).click()
        expect(page.locator('#status')).to_contain_text('Inspected backup restored')
        assert read()['portableArchive']['document']==combined
        fixture_after=combined
        # Exercise shared target cases through decrypt/inspect, preserving both stores on refusal.
        cases=json.loads((CONTRACT/'fixtures/refusal-cases-v1.json').read_text())['cases']
        outcomes=[]
        for case in cases:
            if case.get('target','web')!='web':continue
            base=json.loads((CONTRACT/'fixtures'/case.get('baseFixture','common-weekly-pending.json')).read_text())
            candidate=patched(base,case['operations']);bad=OUTPUT/f"{engine}-case-{case['id']}.linepaybackup";seal(candidate,bad)
            before=read();before_activity=activity();inspect(bad)
            if case.get('activationReview'):
                expect(page.get_by_role('heading',name='Backup inspected; records unchanged')).to_be_visible()
                assert read()==before and activity()==before_activity
                # Inspect does not replace; source calculator context is retained by the adapter.
            else:
                expect(page.locator('#status')).to_have_attribute('role','alert')
                assert read()==before and activity()==before_activity
                assert page.get_by_role('button',name='Replace with inspected backup',exact=True).count()==0
            outcomes.append({'id':case['id'],'outcome':'activation review retained' if case.get('activationReview') else 'refused before replace'})
        page.reload()
        expect(page.get_by_role('heading',name='Expected cash wages',exact=True)).to_be_visible()
        assert read()['portableArchive']['document']==fixture_after
        assert errors==[],errors
        assert runtime_hash()==source_hash and tree_hash()==source_tree_hash, 'Source changed during verification'
        capture=datetime.now(timezone.utc).isoformat()
        immutable=combined_file.with_name(f'{engine}-combined-{hashlib.sha256(combined_file.read_bytes()).hexdigest()}.linepaybackup')
        if immutable.exists():assert immutable.read_bytes()==combined_file.read_bytes()
        else:immutable.write_bytes(combined_file.read_bytes())
        manifest={'captureIteration':capture,'runtimeSHA256':source_hash,'schemaSHA256':schema_hash,'sourceHEAD':source_head,'dirtyWebSourceAndTestsSHA256':source_tree_hash,'browser':engine,'browserVersion':browser.version,'passed':True,'providerInput':str(protected),'providerInputSHA256':hashlib.sha256(protected.read_bytes()).hexdigest(),'download':str(immutable),'downloadSHA256':hashlib.sha256(immutable.read_bytes()).hexdigest(),'syntheticPassword':PHRASE,'sharedCases':outcomes}
        immutable.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (OUTPUT/f'{engine}-report.json').write_text(json.dumps({'immutableManifest':str(immutable.with_suffix('.manifest.json')),'sharedCases':outcomes,'passed':True,'browser':engine,'browserVersion':browser.version,'runtimeSHA256':source_hash,'syntheticPassword':PHRASE,'protectedArtifacts':[{'file':str(file),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()} for file in [output,combined_file]],'checks':['wrong password leaves state intact','full preflight before explicit replacement','native profile/period/work restored','foreign equal-gross weekly-pending verdict frozen','actual encrypted portable download decrypts unchanged','material unknowns block active estimate/check','independent new rounding and context confirmation creates separate lineage','new equal-gross check keeps unresolved rule coverage and pending weekly review','combined original/new facts export and reimport','unsupported fields/attachments preserve destination','relaunch persists source receipts and crosswalk']},indent=2)+'\n')
    except Exception:
        (OUTPUT/f"{engine}-failure.txt").write_text(page.locator("body").inner_text()+"\nErrors: "+json.dumps(errors))
        page.screenshot(path=str(OUTPUT/f"{engine}-failure.png"),full_page=True)
        raise
    finally:
        browser.close();server.shutdown()
