#!/usr/bin/env node
// Package only browser runtime inputs; never publish the repository or test directory.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { copyFile, lstat, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../../", import.meta.url));
const web = path.join(root, "apps/web");
const output = path.join(root, ".build/web-worker/assets");
const receipt = path.join(root, ".build/web-worker/asset-manifest.json");
const check = process.argv.slice(2);
if (check.length > 1 || (check.length === 1 && check[0] !== "--check"))
  throw Error("Usage: node tools/web-worker/build.mjs [--check]");
for (const parent of [".build", ".build/web-worker"]) {
  try {
    if (!(await lstat(path.join(root, parent))).isDirectory())
      throw Error(`Refusing a linked or non-directory build parent: ${parent}`);
  } catch (error) { if (error.code !== "ENOENT") throw error; }
}

async function regularFile(file) {
  if (!(await lstat(file)).isFile()) throw Error(`Expected a regular file: ${file}`);
  return readFile(file);
}
async function filesBelow(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw Error(`Refusing linked asset: ${entry.name}`);
    if (entry.isDirectory()) {
      for (const file of await filesBelow(path.join(directory, entry.name)))
        result.push(`${entry.name}/${file}`);
    } else if (entry.isFile()) result.push(entry.name);
    else throw Error(`Unsupported asset: ${entry.name}`);
  }
  return result.sort();
}
const topLevel = ["index.html", "styles.css", "manifest.webmanifest", "icon.svg", "app-icon.png", "sw.js"];
if (!(await lstat(path.join(web, "src"))).isDirectory()) throw Error("Expected the runtime source directory");
const modules = (await readdir(path.join(web, "src"), { withFileTypes: true }))
  .filter((entry) => entry.isFile() && /^[a-z][a-z0-9-]*\.mjs$/.test(entry.name))
  .map((entry) => `src/${entry.name}`).sort();
const runtime = [...topLevel, ...modules].sort();
const allowed = new Set(runtime);
const contents = new Map();
for (const file of runtime) contents.set(file, await regularFile(path.join(web, file)));
contents.set("_headers", await regularFile(path.join(web, "deploy/_headers")));

function requireAsset(relative, owner) {
  const target = relative.endsWith("/") ? `${relative}index.html` : relative;
  const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(owner), target));
  if (!allowed.has(resolved)) throw Error(`Missing or disallowed runtime reference: ${owner} → ${relative}`);
}
for (const file of modules) {
  const source = contents.get(file).toString("utf8");
  const imports = source.matchAll(/\b(?:import|export)\s+(?:[^;]*?\sfrom\s*)?["']([^"']+)["']|\bimport\(\s*["']([^"']+)["']\s*\)/g);
  for (const match of imports) {
    const reference = match[1] ?? match[2];
    if (!reference.startsWith("./") && !reference.startsWith("../"))
      throw Error(`Runtime import must be local: ${file} → ${reference}`);
    requireAsset(reference, file);
  }
}
for (const match of contents.get("index.html").toString("utf8").matchAll(/(?:src|href)="([^"#]+)"/g))
  requireAsset(match[1], "index.html");
const manifest = JSON.parse(contents.get("manifest.webmanifest"));
for (const icon of manifest.icons) requireAsset(icon.src, "manifest.webmanifest");
const shell = contents.get("sw.js").toString("utf8").match(/const FILES = (\[[\s\S]*?\n\]);/);
if (!shell) throw Error("Cannot inspect the explicit service-worker shell allowlist");
for (const file of JSON.parse(shell[1].replace(/,\s*\]/g, "]")))
  requireAsset(file === "./" ? "index.html" : file, "sw.js");

const entries = [...contents].map(([file, bytes]) => ({
  path: file,
  bytes: bytes.byteLength,
  sha256: createHash("sha256").update(bytes).digest("hex"),
})).sort((a, b) => a.path.localeCompare(b.path, "en"));
if (check.length) {
  const actual = await filesBelow(output);
  const expected = entries.map((entry) => entry.path).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected))
    throw Error("Public asset directory differs from the runtime allowlist; rebuild before deploying");
  for (const entry of entries) {
    const bytes = await regularFile(path.join(output, entry.path));
    if (createHash("sha256").update(bytes).digest("hex") !== entry.sha256)
      throw Error(`Stale or modified public asset: ${entry.path}`);
  }
  const saved = JSON.parse(await readFile(receipt));
  if (JSON.stringify(saved.assets) !== JSON.stringify(entries)) throw Error("Stale asset receipt");
  console.log(`Verified ${entries.length} allowlisted files; no tests, fixtures, tooling or repository files are public.`);
} else {
  // Only this ignored, fixed generated directory is replaced. Never touch browser records.
  await mkdir(path.dirname(output), { recursive: true });
  try { if ((await lstat(output)).isSymbolicLink()) throw Error("Refusing a linked output directory"); }
  catch (error) { if (error.code !== "ENOENT") throw error; }
  await rm(output, { recursive: true, force: true });
  await mkdir(path.join(output, "src"), { recursive: true });
  for (const file of runtime) await copyFile(path.join(web, file), path.join(output, file));
  await copyFile(path.join(web, "deploy/_headers"), path.join(output, "_headers"));
  const commit = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
  await writeFile(receipt, `${JSON.stringify({ sourceCommit: commit, assets: entries }, null, 2)}\n`);
  console.log(`Packaged ${entries.length} allowlisted files into .build/web-worker/assets.`);
}
