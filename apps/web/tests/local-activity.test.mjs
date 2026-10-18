import { test } from "node:test";
import assert from "node:assert/strict";
import {
  emptyLocalActivity,
  LocalActivityLedger,
  validateLocalActivity,
} from "../src/local-activity.mjs";
import { emptyState, snapshot } from "../src/state.mjs";

class MemoryActivityStore {
  constructor(value = null) {
    this.value = value;
    this.readError = null;
    this.writeError = null;
    this.writes = 0;
  }
  async read() {
    if (this.readError) throw this.readError;
    return structuredClone(this.value ?? emptyLocalActivity());
  }
  async update(transform) {
    if (this.writeError) throw this.writeError;
    const update = transform(structuredClone(this.value ?? emptyLocalActivity()));
    validateLocalActivity(update.snapshot);
    if (update.changed) {
      this.value = structuredClone(update.snapshot);
      this.writes += 1;
    }
    return { snapshot: structuredClone(this.value ?? update.snapshot), changed: update.changed };
  }
  async reset(recordingEnabled, generation) {
    if (this.writeError) throw this.writeError;
    const nextGeneration = Math.max(this.value?.generation ?? generation - 1, generation - 1) + 1;
    this.value = emptyLocalActivity(recordingEnabled, nextGeneration);
    this.writes += 1;
    return structuredClone(this.value);
  }
}

const dateClock = (date) => () => new Date(date + "T12:00:00Z");

test("closed milestones aggregate locally, deduplicate internal identities and export no identifiers", async () => {
  const store = new MemoryActivityStore();
  const ledger = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  const periodID = "a1000000-0000-4000-8000-000000000001";
  const workID = "a1000000-0000-4000-8000-000000000002";

  assert.equal(await ledger.record("firstObservedOpen", { kind: "once" }), true);
  assert.equal(await ledger.record("firstObservedOpen", { kind: "once" }), false);
  await ledger.record("appOpened");
  await ledger.record("appOpened");
  assert.equal(await ledger.record("expectedPaySeen", { kind: "period", id: periodID }), true);
  assert.equal(await ledger.record("expectedPaySeen", { kind: "period", id: periodID }), false);
  await ledger.record("workLogged", { kind: "work", id: workID });

  assert.equal(ledger.count("firstObservedOpen"), 1);
  assert.equal(ledger.count("appOpened"), 2);
  assert.equal(ledger.count("expectedPaySeen"), 1);
  assert.equal(ledger.count("workLogged"), 1);
  assert.equal(store.value.deduplicationDigests.length, 3);
  assert.ok(store.value.deduplicationDigests.every((item) => /^[0-9a-f]{64}$/.test(item)));

  const report = JSON.parse(await ledger.diagnosticData());
  assert.equal(report.format, "com.streamentry.linepay.web.local-diagnostics");
  assert.equal(report.recordingEnabled, true);
  assert.equal(report.totals.length, 11);
  assert.equal(report.days[0].dayUTC, "2026-10-19");
  const output = JSON.stringify(report);
  assert.equal(output.includes(periodID), false);
  assert.equal(output.includes(workID), false);
  assert.equal(output.includes("deduplicationDigests"), false);
  assert.equal(output.includes("paidGross"), false);
  const financialBackupShape = JSON.parse(new TextDecoder().decode(snapshot(emptyState())));
  assert.equal("activity" in financialBackupShape.state, false);
  assert.equal(JSON.stringify(financialBackupShape).includes("deduplicationDigests"), false);
});

test("retention is bounded to 400 observed UTC days without changing current-day counts", async () => {
  const store = new MemoryActivityStore();
  let currentDay = "2025-01-01";
  const ledger = await LocalActivityLedger.fromStore(store, () => new Date(currentDay + "T12:00:00Z"));
  const start = new Date("2025-01-01T12:00:00Z");
  for (let offset = 0; offset < 401; offset += 1) {
    currentDay = new Date(start.getTime() + offset * 86_400_000).toISOString().slice(0, 10);
    await ledger.record("appOpened");
  }
  assert.equal(ledger.count("appOpened"), 401);
  assert.equal(ledger.snapshot.days.length, 400);
  assert.equal(ledger.snapshot.prunedDayCount, 1);
  assert.equal(ledger.snapshot.days[0].dayUTC, "2025-01-02");
  assert.equal(ledger.snapshot.days.at(-1).dayUTC, currentDay);
  assert.equal(JSON.parse(await ledger.diagnosticData()).days.length, 400);
});

test("pause and activity-only clear preserve the preference and never mutate pay records", async () => {
  const store = new MemoryActivityStore();
  const ledger = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  const payRecords = { periods: ["SYNTHETIC-PAYCHECK-001"] };
  await ledger.record("workLogged", { kind: "work", id: "a1000000-0000-4000-8000-000000000003" });
  await ledger.setRecordingEnabled(false);
  assert.equal(await ledger.record("appOpened"), false);
  assert.equal(ledger.count("workLogged"), 1);
  assert.equal(ledger.snapshot.recordingPauseCount, 1);
  await ledger.clear();
  assert.equal(ledger.snapshot.recordingEnabled, false);
  assert.equal(ledger.count("workLogged"), 0);
  assert.equal(ledger.snapshot.days.length, 0);
  assert.deepEqual(payRecords, { periods: ["SYNTHETIC-PAYCHECK-001"] });
  assert.equal(JSON.parse(await ledger.diagnosticData()).recordingEnabled, false);
});

test("future or unreadable activity is preserved until explicit activity-only reset", async () => {
  const future = { ...emptyLocalActivity(), version: 2 };
  const store = new MemoryActivityStore(future);
  const ledger = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  assert.equal(ledger.readable, false);
  assert.equal(await ledger.record("appOpened"), false);
  assert.deepEqual(store.value, future);
  const report = JSON.parse(await ledger.diagnosticData());
  assert.equal(report.activityReadable, false);
  assert.equal(report.recordingIssue, true);
  assert.equal(JSON.stringify(report).includes("version\":2"), false);
  assert.equal(store.writes, 0);
  await ledger.clear();
  assert.equal(store.writes, 1);
  assert.equal(store.value.version, 1);
  assert.equal(store.value.recordingEnabled, false);
  assert.equal(ledger.readable, true);

  const broken = new MemoryActivityStore();
  broken.readError = Error("SYNTHETIC private database failure");
  const unreadable = await LocalActivityLedger.fromStore(broken, dateClock("2026-10-19"));
  assert.equal(unreadable.readable, false);
  assert.equal(JSON.stringify(JSON.parse(await unreadable.diagnosticData())).includes("SYNTHETIC private"), false);
});

test("activity write failures stay separate from pay state and appear as incomplete diagnostics", async () => {
  const store = new MemoryActivityStore();
  const ledger = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  const payRecords = { revision: 7 };
  store.writeError = Error("SYNTHETIC local activity write failure");
  assert.equal(await ledger.record("appOpened"), false);
  assert.deepEqual(payRecords, { revision: 7 });
  const report = JSON.parse(await ledger.diagnosticData());
  assert.equal(report.recordingIssue, true);
  assert.equal(report.failedObservationCount, 1);
  assert.equal(JSON.stringify(report).includes("SYNTHETIC local activity write failure"), false);

  store.writeError = null;
  await ledger.record("appOpened");
  assert.equal(ledger.snapshot.failedObservationCount, 1);
  assert.equal(ledger.pendingFailures, 0);
  assert.deepEqual(payRecords, { revision: 7 });
});

test("a tab with a pre-clear activity generation cannot recreate counts after another tab clears", async () => {
  const store = new MemoryActivityStore();
  const firstTab = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  const secondTab = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  await firstTab.record("appOpened");
  await firstTab.clear();
  await firstTab.setRecordingEnabled(false);
  assert.equal(await secondTab.record("workLogged", { kind: "work", id: "a1000000-0000-4000-8000-000000000004" }), false);
  assert.equal(secondTab.snapshot.generation, firstTab.snapshot.generation);
  assert.equal(secondTab.snapshot.recordingEnabled, false);
  assert.equal(secondTab.count("workLogged"), 0);
  await firstTab.setRecordingEnabled(true);
  await secondTab.refresh();
  assert.equal(await secondTab.record("appOpened"), true);
  assert.equal(secondTab.count("appOpened"), 1);
});

test("unknown milestone, identity and snapshot fields fail closed", async () => {
  const store = new MemoryActivityStore();
  const ledger = await LocalActivityLedger.fromStore(store, dateClock("2026-10-19"));
  assert.equal(await ledger.record("privateNote", { kind: "once" }), false);
  assert.equal(await ledger.record("workLogged", { kind: "work", id: "USD-55" }), false);
  assert.equal(await ledger.record("workLogged", { kind: "work", id: "SYNTHETIC-001", value: "55" }), false);
  const unknown = { ...emptyLocalActivity(), employer: "SYNTHETIC employer" };
  assert.throws(() => validateLocalActivity(unknown));
  assert.equal(JSON.stringify(JSON.parse(await ledger.diagnosticData())).includes("privateNote"), false);
});
