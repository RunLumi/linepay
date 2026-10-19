import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";

const web = (path) => new URL(`../${path}`, import.meta.url);
const read = (path) => readFileSync(web(path), "utf8");
const index = read("index.html");
const manifest = JSON.parse(read("manifest.webmanifest"));
const sources = readdirSync(web("src"))
  .filter((name) => name.endsWith(".mjs"))
  .map((name) => [name, read(`src/${name}`)]);
const app = read("src/app.mjs");

test("browser shell uses the v3 public name and subtitle", () => {
  assert.match(index, /<title>Paycheck Audit: LinePay — Verify Pay &amp; Track Hours<\/title>/);
  assert.match(index, /<span class="wordmark">Paycheck Audit: LinePay<\/span\s*>/);
  assert.match(index, /Verify Pay &amp; Track Hours · development preview/);
  assert.equal(manifest.name, "Paycheck Audit: LinePay");
  assert.equal(manifest.short_name, "LinePay");
});

test("technical identity and the preview boundary are unchanged", () => {
  assert.equal(manifest.id, "./");
  assert.equal(manifest.start_url, "./");
  assert.equal(manifest.scope, "./");
  assert.ok(index.includes("development preview"));
  assert.match(read("deploy/_headers"), /X-Robots-Tag: noindex, nofollow/);
  assert.match(read("sw.js"), /const CACHE = "linepaycheck-web-shell-v\d+";/);
});

test("the empty Pay view leads with the v3 headline and promise", () => {
  assert.ok(app.includes("<h1>Is Your Paycheck Correct?</h1>"));
  assert.ok(
    app.includes(
      "Track what you worked. Compare expected pay with your paystub. Understand possible differences.",
    ),
  );
  assert.equal(app.includes("Your work. Your expected pay."), false);
});

test("result labels are the scoped v3 vocabulary, not a legal verdict", () => {
  for (const [name, source] of sources.filter(([n]) =>
    ["app.mjs", "report.mjs"].includes(n),
  )) {
    assert.ok(source.includes('matches: "Match within compared scope"'), name);
    assert.ok(source.includes('notComparable: "Unable to verify"'), name);
    assert.ok(source.includes('possibleShortfall: "Possible shortfall"'), name);
    assert.ok(source.includes('possibleOverpayment: "Possible overpayment"'), name);
    assert.equal(source.includes('"Compared values match"'), false, name);
  }
  const benefits = read("src/benefits-ui.mjs");
  assert.ok(benefits.includes('comparedValuesMatch: "Match within compared scope"'));
  assert.ok(benefits.includes('notComparable: "Unable to verify"'));
  assert.ok(benefits.includes('possibleDifference: "Possible difference"'));
});

test("shipped copy makes none of the claims v3 forbids", () => {
  const forbidden = [
    /wage[- ]theft/i,
    /\bunderpaid\b/i,
    /guaranteed? (?:recovery|refund|money)/i,
    /recover your money/i,
    /you are owed/i,
    /\billegal\b/i,
    /violat(?:es?|ion)/i,
  ];
  for (const [name, text] of [["index.html", index], ...sources])
    for (const pattern of forbidden)
      assert.equal(text.match(pattern), null, `${name} contains forbidden claim ${pattern}`);
  assert.match(index, /not a legal-pay\s+audit/);
  assert.match(index, /No LinePay\s+account/);
});
