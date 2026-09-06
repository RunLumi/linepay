export function normalize(value) {
  return String(value).normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

export function rank(pages, query) {
  const terms = [...new Set(normalize(query).trim().split(/\s+/))].filter(Boolean).slice(0, 8);
  if (!terms.length) return [];
  return pages.map(page => {
    const title = normalize(page.title);
    const summary = normalize(page.description + ' ' + (page.keywords || []).join(' '));
    const body = normalize(page.text);
    let score = 0;
    for (const term of terms) {
      if (title.includes(term)) score += 12;
      else if (summary.includes(term)) score += 5;
      else if (body.includes(term)) score += 1;
      else return { page, score: 0 };
    }
    return { page, score };
  }).filter(hit => hit.score > 0).sort((a, b) => b.score - a.score || a.page.title.localeCompare(b.page.title)).slice(0, 12).map(hit => hit.page);
}

if (typeof document !== 'undefined') {
  const form = document.querySelector('#guide-search');
  const input = document.querySelector('#search-input');
  const status = document.querySelector('#search-status');
  const results = document.querySelector('#search-results');
  let indexPromise;
  let generation = 0;
  if (form && input && status && results) {
    form.hidden = false;
    async function search() {
      const current = ++generation;
      const query = input.value.trim();
      results.replaceChildren();
      if (!query) { status.textContent = 'Enter a few words to find a guide.'; return; }
      status.textContent = 'Searching the guide…';
      try {
        indexPromise ||= fetch(form.dataset.index, { credentials: 'omit' }).then(response => {
          if (!response.ok) throw new Error('Index unavailable');
          return response.json();
        }).catch(error => { indexPromise = undefined; throw error; });
        const pages = await indexPromise;
        if (current !== generation) return;
        const found = rank(pages, query);
        for (const page of found) {
          const target = new URL(page.url, location.origin);
          if (target.origin !== location.origin || !['http:', 'https:'].includes(target.protocol)) continue;
          const item = document.createElement('li');
          const link = document.createElement('a');
          link.href = target.href;
          link.textContent = page.title;
          const description = document.createElement('p');
          description.textContent = page.description;
          item.append(link, description);
          results.append(item);
        }
        const count = results.children.length;
        status.textContent = count ? `${count} matching guide${count === 1 ? '' : 's'}.` : 'No matching guides. Try fewer words, or browse the index below.';
      } catch {
        if (current === generation) status.textContent = 'Search could not load. Browse the guides below, or try again when connected.';
      }
    }
    input.addEventListener('input', search);
    form.addEventListener('submit', event => { event.preventDefault(); search(); });
  }
}
