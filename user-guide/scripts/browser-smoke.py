"""Optional real-browser QA; never sends source or user records to a remote test service."""
from __future__ import annotations
import json
import os
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

def run():
    evidence = ROOT / '.qa/browser'
    evidence.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(ROOT / '.qa/project')))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f'http://127.0.0.1:{server.server_port}/linepay/'
    records = []
    try:
        with sync_playwright() as p:
            options = {'headless': True}
            if os.environ.get('CHROMIUM_PATH'): options['executable_path'] = os.environ['CHROMIUM_PATH']
            browser = p.chromium.launch(**options)
            slugs = ['', 'getting-started/', 'paystub-layouts/', 'backup-and-restore/', 'search/']
            for name, width, height, theme in [('desktop-light', 1440, 1000, 'light'), ('mobile-light', 390, 844, 'light'), ('small-dark', 320, 780, 'dark')]:
                context = browser.new_context(viewport={'width': width, 'height': height}, color_scheme=theme, reduced_motion='reduce')
                page = context.new_page()
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                for slug in slugs:
                    response = page.goto(base + slug)
                    assert response and response.ok
                    page.locator('h1').wait_for()
                    assert page.locator('h1').count() == 1
                    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth + 1'), f'Horizontal overflow: {name}/{slug}'
                    assert page.locator('main').is_visible()
                    records.append({'configuration': name, 'path': slug or '/', 'status': 'passed'})
                page.goto(base)
                page.screenshot(path=str(evidence / f'{name}-home.png'), full_page=True)
                if width < 1024:
                    nav = page.locator('#guide-navigation')
                    assert not nav.evaluate('(node) => node.open')
                    nav.locator('summary').click()
                    assert nav.evaluate('(node) => node.open')
                    page.get_by_role('navigation', name='User guide', exact=True).get_by_role('link', name='Backup and restore', exact=True).click()
                    assert page.url.endswith('/backup-and-restore/')
                page.goto(base + 'search/')
                field = page.get_by_label('Search the user guide', exact=True)
                field.fill('backup')
                result = page.locator('#search-results a').filter(has_text='Back up, restore, and move iPhones')
                result.wait_for()
                result.click()
                assert page.url.endswith('/backup-and-restore/')
                page.get_by_label('Appearance', exact=True).select_option('dark')
                page.reload()
                assert page.locator('html').get_attribute('data-theme') == 'dark'
                page.screenshot(path=str(evidence / f'{name}-article.png'), full_page=True)
                page.goto(base + 'search/')
                field = page.get_by_label('Search the user guide', exact=True)
                field.fill('not-a-real-guide-xyz')
                page.get_by_role('status').filter(has_text='No matching guides').wait_for()
                field.fill('<img src=x onerror=alert(1)>')
                page.get_by_role('status').filter(has_text='No matching guides').wait_for()
                assert page.locator('#search-results img').count() == 0
                field.fill('')
                assert page.locator('#search-results li').count() == 0
                assert not errors, errors
                context.close()
            context = browser.new_context(java_script_enabled=False, viewport={'width': 390, 'height': 844})
            page = context.new_page()
            page.goto(base + 'getting-started/')
            assert page.get_by_role('navigation', name='User guide', exact=True).is_visible()
            assert page.locator('main').inner_text().find('Set up your pay') >= 0
            page.goto(base + 'search/')
            assert page.get_by_text('All guides remain available', exact=False).is_visible()
            assert page.locator('.browse-list a').count() == 20
            context.close()
            context = browser.new_context(viewport={'width': 390, 'height': 844})
            page = context.new_page()
            page.goto(base + 'getting-started/')
            page.keyboard.press('Tab')
            assert page.locator('.skip-link').evaluate('(node) => node === document.activeElement')
            page.keyboard.press('Enter')
            assert page.locator('main').evaluate('(node) => node === document.activeElement')
            page.emulate_media(media='print')
            assert not page.locator('.sidebar').is_visible()
            assert page.locator('main').is_visible()
            context.close()
            browser.close()
        (evidence / 'results.json').write_text(json.dumps({'checks': records, 'search_theme_navigation_nojs_keyboard_print': 'passed'}, indent=2))
        print(f'PASS: {len(records)} browser page/configuration checks; mobile navigation, real search, dark preference, no-JS, keyboard skip link, print layout')
    finally:
        server.shutdown()
        server.server_close()

if __name__ == '__main__': run()
