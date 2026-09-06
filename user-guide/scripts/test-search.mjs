import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../assets/js/search.js', import.meta.url), 'utf8');
const { normalize, rank } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const pages = [
  { title: 'Backup and restore', description: 'Move iPhones safely', text: 'Manual iCloud backup, never live sync.', url: '/linepay/backup/', keywords: ['recovery'] },
  { title: 'Pay rules', description: 'Configure per diem and overtime', text: 'Keep a backup before changes.', url: '/linepay/rules/' },
];
assert.equal(normalize('CAFÉ'), 'cafe');
assert.deepEqual(rank(pages, ' '), []);
assert.equal(rank(pages, 'backup')[0].title, 'Backup and restore');
assert.equal(rank(pages, 'PER DIEM')[0].title, 'Pay rules');
assert.equal(rank(pages, 'recovery')[0].title, 'Backup and restore');
assert.deepEqual(rank(pages, 'backup unicorn'), []);
assert.deepEqual(rank(pages, '<img src=x onerror=alert(1)>'), []);
assert.deepEqual(rank(pages, '$400.00'), []);
assert.equal(rank(pages, 'backup backup')[0].url, '/linepay/backup/');
const real = JSON.parse(readFileSync(new URL('../.qa/project/linepay/index.json', import.meta.url)));
for (const [query, suffix] of [['backup', '/backup-and-restore/'], ['per diem', '/pay-rules/'], ['gross', '/paystub-layouts/'], ['trial', '/pro-and-billing/']]) {
  assert(rank(real, query).some(page => page.url.endsWith(suffix)), `Missing relevant result for ${query}`);
}
console.log('PASS: deterministic search ranking, multiple terms, case/diacritics, empty/no-match/literal input, real index relevance');
