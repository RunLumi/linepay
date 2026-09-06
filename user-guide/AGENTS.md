# Public user-guide contract

Follow root AGENTS.md. This Hugo site is public user help, not an export of internal `docs/`.

- Read the actual release UI and behavior before writing steps. Product plans are intent, not proof of implementation. Record source coverage in CONTENT-SOURCES.md.
- Use LinePaycheck, the exact visible control names, and plain English. Do not expose internal type names or pretend the website is the app.
- Preserve DESIGN.md's semantic palette, system typography, opaque reading surfaces, accessible controls, and editorial-ledger structure.
- Never invent screenshots, supported rules, subscription offers, payout recovery, encryption, automatic sync, or successful release/device validation.
- Keep uncertain facts, confirmed fields, rule applicability, and audit scope distinct. Existing user data must not be presented as a subscription hostage.
- Only `content/`, authored assets, and `static/` are published. Never mount repository root or internal docs into Hugo.
- No external fonts, analytics, search service, runtime framework, cookies, or server. Search queries stay in the browser; local storage holds only appearance preference.
- Links must survive both `/` and `/linepay/` deployment. Use Hugo relref/GetPage/RelPermalink, never hard-code the hosting prefix into guides.
- Run `bash scripts/check.sh` here before handoff. Browser checks require the optional pinned test dependency; see README.md.
- Do not commit generated `public/`, diagnostics, screenshots, credentials, or private paystub data. Do not enable public deployment or change domains/repository visibility incidentally.
