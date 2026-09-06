"""CSS fixture regressions, not a substitute for a Hugo build or site E2E run."""
from __future__ import annotations
import json
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def run() -> None:
    css = (ROOT / 'assets/css/guide.css').read_text()
    records = []
    with sync_playwright() as p:
        options = {'headless': True}
        if os.environ.get('CHROMIUM_PATH'):
            options['executable_path'] = os.environ['CHROMIUM_PATH']
        browser = p.chromium.launch(**options)
        try:
            for theme, system in [('auto', 'dark'), ('dark', 'light'), ('light', 'light')]:
                page = browser.new_page(color_scheme=system)
                attrs = '' if theme == 'auto' else f' data-theme="{theme}"'
                page.set_content(
                    f'<!doctype html><html{attrs}><head><style>{css}</style></head>'
                    '<body><h1>Fixture heading</h1><p class="lead">Important context</p>'
                    '<section class="sample-ledger">Expected wages</section></body></html>'
                )
                page.emulate_media(media='print', color_scheme=system)
                colors = page.evaluate('''() => ({
                    lead: getComputedStyle(document.querySelector('.lead')).color,
                    surface: getComputedStyle(document.querySelector('.sample-ledger')).backgroundColor,
                    body: getComputedStyle(document.body).backgroundColor
                })''')
                assert colors == {
                    'lead': 'rgb(34, 34, 34)',
                    'surface': 'rgb(255, 255, 255)',
                    'body': 'rgb(255, 255, 255)',
                }, (theme, colors)
                records.append({'theme': theme, 'mode': 'print', 'status': 'passed'})
                page.emulate_media(media='screen', color_scheme=system, contrast='more')
                assert page.evaluate('''
                    getComputedStyle(document.querySelector('.lead')).color ===
                    getComputedStyle(document.querySelector('h1')).color
                '''), f'Important supporting text did not strengthen in {theme}'
                records.append({'theme': theme, 'mode': 'increased contrast', 'status': 'passed'})
                page.close()
        finally:
            browser.close()
    output = ROOT / '.qa/css'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'results.json').write_text(json.dumps({
        'scope': 'Authored CSS on synthetic HTML fixtures; not generated Hugo pages',
        'checks': records,
    }, indent=2))
    print('PASS: six CSS fixture checks across print/increased contrast and system/dark/light appearance')


if __name__ == '__main__':
    run()
