import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const css = readFileSync(new URL("../styles.css", import.meta.url), "utf8");
function theme(block) {
  return Object.fromEntries(
    [...block.matchAll(/--([a-z]+):\s*(#[0-9a-f]{3}(?:[0-9a-f]{3})?)\s*;/gi)].map(([, name, value]) => [
      name,
      value.length === 4 ? `#${[...value.slice(1)].map((digit) => digit + digit).join("")}` : value,
    ]),
  );
}
function luminance(hex) {
  const channels = [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255);
  const linear = channels.map((value) =>
    value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4,
  );
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}
function contrast(foreground, background) {
  const [high, low] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (high + 0.05) / (low + 0.05);
}

test("light/dark interface tokens meet text and control contrast thresholds", () => {
  const lightBlock = css.match(/:root\s*\{([^}]+)\}/)?.[1];
  const darkBlock = css.match(/@media \(prefers-color-scheme: dark\)\s*\{\s*:root\s*\{([^}]+)\}/)?.[1];
  assert.ok(lightBlock && darkBlock, "both explicit color themes are defined");
  const themes = { light: theme(lightBlock), dark: theme(darkBlock) };
  for (const [name, values] of Object.entries(themes)) {
    for (const surface of ["canvas", "surface"]) {
      for (const text of ["text", "secondary", "action", "error"]) {
        const ratio = contrast(values[text], values[surface]);
        assert.ok(ratio >= 4.5, `${name} ${text} on ${surface}: ${ratio.toFixed(2)}:1`);
      }
      const borderRatio = contrast(values.line, values[surface]);
      assert.ok(borderRatio >= 3, `${name} control border on ${surface}: ${borderRatio.toFixed(2)}:1`);
    }
    assert.ok(
      contrast(values.fill, values.onfill) >= 4.5,
      `${name} primary-button text: ${contrast(values.fill, values.onfill).toFixed(2)}:1`,
    );
  }
});
