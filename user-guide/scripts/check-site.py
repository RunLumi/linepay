"""Validate generated HTML, search URLs and fragments at both hosting bases. Stdlib only."""
from __future__ import annotations
import json
import sys
from decimal import Decimal
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

class Page(HTMLParser):
    def __init__(self, text: str):
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.duplicates: list[str] = []
        self.links: list[str] = []
        self.h1 = 0
        self.main = 0
        self.title = 0
        self.description = False
        self.canonical = ''
        self.lang = ''
        self.scripts: list[str] = []
        self.feed(text)
    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        identity = attrs.get('id')
        if identity:
            if identity in self.ids: self.duplicates.append(identity)
            self.ids.add(identity)
        self.h1 += tag == 'h1'
        self.main += tag == 'main'
        self.title += tag == 'title'
        if tag == 'html': self.lang = attrs.get('lang', '')
        if tag == 'meta' and attrs.get('name') == 'description':
            self.description = bool(attrs.get('content'))
        if tag == 'link' and attrs.get('rel') == 'canonical': self.canonical = attrs.get('href', '')
        for key in ('href', 'src'):
            if attrs.get(key): self.links.append(attrs[key])
        if tag == 'script': self.scripts.append(attrs.get('src', ''))

def validate(root: Path, base: str) -> None:
    root = root.resolve()
    origin = urlsplit(base)
    prefix = origin.path
    assert prefix.endswith('/'), 'Base URL must have a trailing slash'
    parsed = {p: Page(p.read_text()) for p in root.rglob('*.html')}
    assert len(parsed) >= 23, f'Expected complete guide, search and 404; got {len(parsed)} pages'
    failures: list[str] = []
    def target(url: str, source: str):
        value = urlsplit(urljoin(source, url))
        if value.scheme not in ('http', 'https'):
            if value.scheme not in ('mailto', 'tel'): failures.append(f'Unsupported URL: {url}')
            return
        if value.netloc != origin.netloc: return
        if not value.path.startswith(prefix):
            failures.append(f'Escapes base {prefix}: {url}')
            return
        relative = unquote(value.path[len(prefix):])
        path = (root / relative).resolve()
        if not path.is_relative_to(root):
            failures.append(f'Unsafe path: {url}')
            return
        if path.is_dir(): path /= 'index.html'
        if not path.is_file():
            failures.append(f'Missing target: {url}')
        elif value.fragment and path.suffix == '.html':
            destination = parsed.get(path)
            if destination and unquote(value.fragment) not in destination.ids:
                failures.append(f'Missing fragment: {url}')
    for path, page in parsed.items():
        relative = path.relative_to(root).as_posix()
        url = urljoin(base, relative.removesuffix('index.html'))
        if page.h1 != 1 or page.main != 1 or page.title != 1: failures.append(f'Landmarks/headings: {relative}')
        if not page.description or not page.canonical or page.lang != 'en-US': failures.append(f'Metadata: {relative}')
        if page.duplicates: failures.append(f'Duplicate IDs in {relative}: {page.duplicates}')
        if not page.canonical.startswith(base): failures.append(f'Wrong canonical: {relative}')
        for script in page.scripts:
            if not script or urlsplit(urljoin(url, script)).netloc != origin.netloc:
                failures.append(f'Inline/external script: {relative}')
        for link in page.links: target(link, url)
    index = json.loads((root / 'index.json').read_text())
    assert len(index) == 20, f'Expected 20 indexed guides, got {len(index)}'
    assert len({item['url'] for item in index}) == len(index)
    for item in index:
        assert item['title'] and item['description'] and len(item['text']) > 300
        target(item['url'], base)
    for name in ('README.md', 'AGENTS.md', 'CONTENT-SOURCES.md', '.git', 'scripts', 'docs'):
        assert not (root / name).exists(), f'Internal material published: {name}'
    assert (root / '.nojekyll').is_file()
    assert (root / 'sitemap.xml').is_file()
    assert (root / '404.html').is_file()
    assert Decimal(40) * 58 + Decimal(6) * 58 * 2 == 3016
    assert Decimal(3016) - 2900 == 116
    if failures: raise AssertionError('\n'.join(failures))
    print(f'PASS: {len(parsed)} HTML pages, {len(index)} search entries, all internal links/fragments/assets, base {prefix}')

if __name__ == '__main__':
    if len(sys.argv) != 3: raise SystemExit('usage: check-site.py OUTPUT_DIR BASE_URL')
    validate(Path(sys.argv[1]), sys.argv[2])
