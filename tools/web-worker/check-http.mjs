#!/usr/bin/env node
// Compare the actual HTTP boundary against the locally built receipt, without user records.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";

const base = new URL(process.argv[2] ?? "http://127.0.0.1:8787/");
assert.equal(base.pathname, "/", "Probe the app's root origin");
assert.equal(base.search + base.hash + base.username + base.password, "", "Use a plain origin without data or credentials");
assert.ok(base.protocol === "https:" || (base.protocol === "http:" && ["127.0.0.1", "localhost", "[::1]"].includes(base.hostname)), "Use HTTPS, or an explicit local loopback origin");
const receipt = JSON.parse(await readFile(new URL("../../.build/web-worker/asset-manifest.json", import.meta.url)));
const mime = new Map([["html", "text/html"], ["css", "text/css"], ["webmanifest", "application/manifest+json"], ["svg", "image/svg+xml"], ["png", "image/png"]]);
async function request(path, options = {}) {
  return fetch(new URL(path, base), { redirect: "manual", signal: AbortSignal.timeout(15000), ...options });
}
let checked = 0;
for (const asset of receipt.assets.filter((entry) => entry.path !== "_headers")) {
  const route = asset.path === "index.html" ? "/" : `/${asset.path}`;
  const response = await request(route);
  assert.equal(response.status, 200, `${route} must serve its actual asset`);
  const extension = asset.path.split(".").at(-1);
  const contentType = response.headers.get("content-type") ?? "";
  if (["mjs", "js"].includes(extension)) assert.match(contentType, /^(?:text|application)\/javascript(?:;|$)/, route);
  else assert.ok(contentType.startsWith(mime.get(extension)), `${route} has the expected MIME`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  assert.equal(createHash("sha256").update(bytes).digest("hex"), asset.sha256, `${route} matches the built source`);
  assert.equal(response.headers.get("x-content-type-options"), "nosniff", route);
  assert.equal(response.headers.get("referrer-policy"), "no-referrer", route);
  assert.equal(response.headers.get("cross-origin-resource-policy"), "same-origin", route);
  assert.match(response.headers.get("content-security-policy") ?? "", /frame-ancestors 'self'/, route);
  assert.match(response.headers.get("cache-control") ?? "", /max-age=0/, route);
  assert.match(response.headers.get("cache-control") ?? "", /must-revalidate/, route);
  assert.match(response.headers.get("cache-control") ?? "", /no-transform/, route);
  assert.doesNotMatch(response.headers.get("cache-control") ?? "", /immutable/, route);
  assert.equal(response.headers.get("set-cookie"), null, route);
  if (route === "/sw.js") assert.equal(response.headers.get("service-worker-allowed"), "/");
  checked++;
}
for (const path of ["/README.md", "/tests/fixtures/web-state-v1.json", "/requirements-test.txt", "/package.json", "/wrangler.jsonc", "/.env", "/.git/config", "/_headers", "/asset-manifest.json", "/src/missing.mjs", "/api/paychecks"]) {
  const response = await request(path);
  assert.equal(response.status, 404, `${path} must not expose private files or an app-shell fallback`);
  await response.arrayBuffer();
}
const post = await request("/", { method: "POST", body: "synthetic-no-pay-data" });
assert.equal(post.status, 405, "The asset-only origin must not accept pay submissions");
await post.arrayBuffer();
console.log(`HTTP checks passed: ${checked} byte-matched runtime assets, headers/MIME, 11 refusals and POST rejection at ${base.origin}.`);
