// Cache only the versioned app shell, never user records, exports or arbitrary fetches.
const CACHE = "linepaycheck-web-shell-v14";
const FILES = [
  "./",
  "index.html",
  "styles.css",
  "manifest.webmanifest",
  "icon.svg",
  "app-icon.png",
  "src/bootstrap.mjs",
  "src/app.mjs",
  "src/decimal.mjs",
  "src/payroll.mjs",
  "src/payroll-v2.mjs",
  "src/calculation-context.mjs",
  "src/rule-timeline-ui.mjs",
  "src/assessment.mjs",
  "src/assessment-lines.mjs",
  "src/assessment-lines-ui.mjs",
  "src/assessment-period.mjs",
  "src/paycycle.mjs",
  "src/period-setup-ui.mjs",
  "src/weekly.mjs",
  "src/weekly-ui.mjs",
  "src/benefits.mjs",
  "src/benefits-ui.mjs",
  "src/rule-template.mjs",
  "src/rule-template-ui.mjs",
  "src/resolution.mjs",
  "src/report.mjs",
  "src/resolution-report-ui.mjs",
  "src/state.mjs",
  "src/backup.mjs",
  "src/local-activity.mjs",
  "src/diagnostics-ui.mjs",
];
self.addEventListener("install", (event) =>
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES))),
);
// No skipWaiting or forced reload: an open form keeps the code version it loaded.
self.addEventListener("activate", (event) =>
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (k) => k.startsWith("linepaycheck-web-shell-") && k !== CACHE,
            )
            .map((k) => caches.delete(k)),
        ),
      ),
  ),
);
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (
    url.origin !== self.location.origin ||
    !FILES.some(
      (file) => new URL(file, self.registration.scope).href === url.href,
    )
  )
    return;
  event.respondWith(
    caches
      .open(CACHE)
      .then((cache) =>
        cache.match(event.request).then((hit) => hit || fetch(event.request)),
      ),
  );
});
