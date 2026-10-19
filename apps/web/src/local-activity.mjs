const FORMAT = "com.streamentry.linepay.web.activity";
const VERSION = 1;
const DATABASE = "linepaycheck-web-activity";
const STORE = "activity";
const MAX_DAYS = 400;
const MAX_DIGESTS = 20_000;
const MAX_COUNT = 1_000_000_000;
const LOCAL_ID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const MILESTONES = Object.freeze([
  "firstObservedOpen",
  "appOpened",
  "profileStarted",
  "profileReady",
  "workLogged",
  "expectedPaySeen",
  "paycheckIntakeStarted",
  "paycheckCheckSaved",
  "auditCompleted",
  "secondAudit",
  "backupRestored",
]);
const MILESTONE_SET = new Set(MILESTONES);
const need = (condition, text) => {
  if (!condition) throw Error(text);
};
const copy = (value) => structuredClone(value);

export const localActivityMilestones = MILESTONES;

export function emptyLocalActivity(recordingEnabled = true, generation = 0) {
  return {
    format: FORMAT,
    version: VERSION,
    generation,
    recordingEnabled,
    firstObservedDayUTC: null,
    days: [],
    totals: [],
    deduplicationDigests: [],
    prunedDayCount: 0,
    failedObservationCount: 0,
    recordingPauseCount: 0,
  };
}

function validDay(value) {
  return (
    typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    new Date(value + "T00:00:00Z").toISOString().slice(0, 10) === value
  );
}

export function validateLocalActivity(value) {
  const fields = [
    "format",
    "version",
    "generation",
    "recordingEnabled",
    "firstObservedDayUTC",
    "days",
    "totals",
    "deduplicationDigests",
    "prunedDayCount",
    "failedObservationCount",
    "recordingPauseCount",
  ];
  need(
    value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      Object.keys(value).sort().join("|") === fields.slice().sort().join("|"),
    "Unsupported local activity fields; nothing was replaced.",
  );
  need(
    value.format === FORMAT && value.version === VERSION,
    "Unsupported local activity version; it has not been overwritten.",
  );
  need(
    Number.isSafeInteger(value.generation) &&
      value.generation >= 0 &&
      value.generation < MAX_COUNT,
    "Invalid local activity generation.",
  );
  need(typeof value.recordingEnabled === "boolean", "Invalid activity preference.");
  need(
    value.firstObservedDayUTC === null || validDay(value.firstObservedDayUTC),
    "Invalid first activity day.",
  );
  for (const field of [
    "prunedDayCount",
    "failedObservationCount",
    "recordingPauseCount",
  ])
    need(
      Number.isSafeInteger(value[field]) &&
        value[field] >= 0 &&
        value[field] <= MAX_COUNT,
      "Invalid local activity counter.",
    );
  const validateTallies = (tallies) => {
    need(Array.isArray(tallies) && tallies.length <= MILESTONES.length, "Invalid activity totals.");
    const seen = new Set();
    for (const tally of tallies) {
      need(
        tally &&
          typeof tally === "object" &&
          Object.keys(tally).sort().join("|") === "count|milestone" &&
          MILESTONE_SET.has(tally.milestone) &&
          Number.isSafeInteger(tally.count) &&
          tally.count >= 1 &&
          tally.count <= MAX_COUNT &&
          !seen.has(tally.milestone),
        "Invalid local activity tally.",
      );
      seen.add(tally.milestone);
    }
  };
  validateTallies(value.totals);
  need(Array.isArray(value.days) && value.days.length <= MAX_DAYS, "Invalid activity days.");
  const days = new Set();
  let previous = "";
  for (const day of value.days) {
    need(
      day &&
        typeof day === "object" &&
        Object.keys(day).sort().join("|") === "dayUTC|tallies" &&
        validDay(day.dayUTC) &&
        !days.has(day.dayUTC) &&
        day.dayUTC > previous,
      "Invalid local activity day.",
    );
    validateTallies(day.tallies);
    days.add(day.dayUTC);
    previous = day.dayUTC;
  }
  need(
    Array.isArray(value.deduplicationDigests) &&
      value.deduplicationDigests.length <= MAX_DIGESTS &&
      new Set(value.deduplicationDigests).size === value.deduplicationDigests.length &&
      value.deduplicationDigests.every((item) => /^[0-9a-f]{64}$/.test(item)),
    "Invalid local activity deduplication data.",
  );
  return value;
}

function requestError(request, message) {
  return request.error || Error(message);
}

export function openLocalActivityStore(indexedDB = globalThis.indexedDB) {
  if (!indexedDB) return Promise.reject(Error("Browser activity storage is unavailable."));
  return new Promise((resolve, reject) => {
    let settled = false;
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE))
        request.result.createObjectStore(STORE);
    };
    request.onerror = () => {
      settled = true;
      reject(requestError(request, "Browser activity storage could not open."));
    };
    request.onblocked = () => {
      settled = true;
      reject(Error("Close other LinePay tabs before opening local activity."));
    };
    request.onsuccess = () => {
      const db = request.result;
      if (settled) {
        db.close();
        return;
      }
      db.onversionchange = () => db.close();
      resolve({
        read: () =>
          new Promise((done, fail) => {
            let result;
            let tx;
            try {
              tx = db.transaction(STORE, "readonly");
              const get = tx.objectStore(STORE).get("current");
              get.onsuccess = () => {
                try {
                  result = validateLocalActivity(get.result ?? emptyLocalActivity());
                } catch (error) {
                  fail(error);
                }
              };
              tx.oncomplete = () => done(copy(result));
              tx.onerror = () => fail(tx.error || Error("Activity read failed."));
              tx.onabort = () => fail(tx.error || Error("Activity read was cancelled."));
            } catch (error) {
              fail(error);
            }
          }),
        update: (transform) =>
          new Promise((done, fail) => {
            let tx;
            let result;
            let changed = false;
            let caught;
            try {
              tx = db.transaction(STORE, "readwrite", { durability: "strict" });
              const objectStore = tx.objectStore(STORE);
              const get = objectStore.get("current");
              get.onsuccess = () => {
                try {
                  const original = validateLocalActivity(get.result ?? emptyLocalActivity());
                  const update = transform(copy(original));
                  result = validateLocalActivity(update.snapshot);
                  changed = update.changed;
                  if (changed) objectStore.put(result, "current");
                } catch (error) {
                  caught = error;
                  tx.abort();
                }
              };
              tx.oncomplete = () => done({ snapshot: copy(result), changed });
              tx.onerror = () => {};
              tx.onabort = () =>
                fail(caught || tx.error || Error("Activity storage could not commit."));
            } catch (error) {
              fail(error);
            }
          }),
        reset: (recordingEnabled, generation) =>
          new Promise((done, fail) => {
            let tx;
            let result;
            try {
              tx = db.transaction(STORE, "readwrite", { durability: "strict" });
              const objectStore = tx.objectStore(STORE);
              const get = objectStore.get("current");
              get.onsuccess = () => {
                const current = get.result?.generation;
                const base =
                  Number.isSafeInteger(current) && current >= 0
                    ? Math.max(current, generation - 1)
                    : generation - 1;
                result = emptyLocalActivity(recordingEnabled, Math.min(MAX_COUNT - 1, base + 1));
                objectStore.put(result, "current");
              };
              tx.oncomplete = () => done(copy(result));
              tx.onerror = () => {};
              tx.onabort = () =>
                fail(tx.error || Error("Local activity could not be cleared."));
            } catch (error) {
              fail(error);
            }
          }),
        close: () => db.close(),
      });
    };
  });
}

function deleteLocalActivityDatabase(indexedDB = globalThis.indexedDB) {
  if (!indexedDB) return Promise.reject(Error("Browser activity storage is unavailable."));
  return new Promise((resolve, reject) => {
    let settled = false;
    const request = indexedDB.deleteDatabase(DATABASE);
    request.onsuccess = () => {
      if (settled) return;
      settled = true;
      resolve();
    };
    request.onerror = () => {
      if (settled) return;
      settled = true;
      reject(request.error || Error("Local activity could not be reset."));
    };
    request.onblocked = () => {
      if (settled) return;
      settled = true;
      reject(Error("Close other LinePay tabs before clearing local activity."));
    };
  });
}

export class LocalActivityLedger {
  constructor({ store = null, now = () => new Date(), snapshot = emptyLocalActivity(false), readable = false, issue = null } = {}) {
    this.store = store;
    this.now = now;
    this.snapshot = snapshot;
    this.readable = readable;
    this.issue = issue;
    this.pendingFailures = 0;
    this.operationQueue = Promise.resolve();
  }

  static async open({ indexedDB = globalThis.indexedDB, now = () => new Date() } = {}) {
    let store = null;
    try {
      store = await openLocalActivityStore(indexedDB);
    } catch {
      return new LocalActivityLedger({
        now,
        issue:
          "Local activity could not be read. It has not been overwritten. Pay records are separate; clear only this activity to restart it.",
      });
    }
    return LocalActivityLedger.fromStore(store, now);
  }

  static async fromStore(store, now = () => new Date()) {
    try {
      const snapshot = validateLocalActivity(await store.read());
      return new LocalActivityLedger({ store, now, snapshot, readable: true });
    } catch {
      return new LocalActivityLedger({
        store,
        now,
        issue:
          "Local activity could not be read. It has not been overwritten. Pay records are separate; clear only this activity to restart it.",
      });
    }
  }

  count(milestone) {
    return this.snapshot.totals.find((row) => row.milestone === milestone)?.count ?? 0;
  }

  enqueue(operation) {
    const pending = this.operationQueue.then(operation, operation);
    this.operationQueue = pending.catch(() => {});
    return pending;
  }

  record(milestone, identity = null) {
    return this.enqueue(() => this.recordNow(milestone, identity));
  }

  async recordNow(milestone, identity = null) {
    if (!this.readable || !this.snapshot.recordingEnabled) return false;
    try {
      need(MILESTONE_SET.has(milestone), "Unsupported activity milestone.");
      let digest = null;
      if (identity !== null) {
        need(
          identity &&
            typeof identity === "object" &&
            ["once", "period", "work"].includes(identity.kind) &&
            (identity.kind === "once"
              ? Object.keys(identity).join("|") === "kind"
              : Object.keys(identity).sort().join("|") === "id|kind" &&
                typeof identity.id === "string" &&
                LOCAL_ID.test(identity.id)),
          "Invalid local activity identity.",
        );
        const token = identity.kind === "once" ? "once" : `${identity.kind}:${identity.id}`;
        const bytes = new TextEncoder().encode(`${milestone}|${token}`);
        const hashed = await crypto.subtle.digest("SHA-256", bytes);
        digest = Array.from(new Uint8Array(hashed), (byte) => byte.toString(16).padStart(2, "0")).join("");
      }
      const dayUTC = this.now().toISOString().slice(0, 10);
      const result = await this.store.update((current) => {
        if (
          current.generation !== this.snapshot.generation ||
          !current.recordingEnabled
        )
          return { snapshot: current, changed: false };
        if (identity?.kind === "once" && current.totals.some((item) => item.milestone === milestone))
          return { snapshot: current, changed: false };
        if (digest && current.deduplicationDigests.includes(digest))
          return { snapshot: current, changed: false };
        const value = current;
        if (this.pendingFailures > 0) {
          value.failedObservationCount = Math.min(
            MAX_COUNT,
            value.failedObservationCount + this.pendingFailures,
          );
        }
        if (digest) {
          value.deduplicationDigests.push(digest);
          if (value.deduplicationDigests.length > MAX_DIGESTS)
            value.deduplicationDigests.splice(0, value.deduplicationDigests.length - MAX_DIGESTS);
        }
        const increment = (tallies) => {
          const existing = tallies.find((item) => item.milestone === milestone);
          if (existing) {
            need(existing.count < MAX_COUNT, "Local activity counter limit reached.");
            existing.count += 1;
          } else tallies.push({ milestone, count: 1 });
        };
        increment(value.totals);
        if (value.firstObservedDayUTC === null) value.firstObservedDayUTC = dayUTC;
        let day = value.days.find((item) => item.dayUTC === dayUTC);
        if (!day) {
          day = { dayUTC, tallies: [] };
          value.days.push(day);
          value.days.sort((a, b) => a.dayUTC.localeCompare(b.dayUTC));
        }
        increment(day.tallies);
        while (value.days.length > MAX_DAYS) {
          value.days.shift();
          need(value.prunedDayCount < MAX_COUNT, "Local activity retention limit reached.");
          value.prunedDayCount += 1;
        }
        return { snapshot: value, changed: true };
      });
      this.snapshot = result.snapshot;
      if (result.changed) this.pendingFailures = 0;
      this.issue = null;
      return result.changed;
    } catch {
      this.pendingFailures = Math.min(MAX_COUNT, this.pendingFailures + 1);
      this.issue =
        "A local activity observation could not be saved. Pay records are unchanged. Counts may be incomplete; check local storage.";
      return false;
    }
  }

  setRecordingEnabled(enabled) {
    return this.enqueue(() => this.setRecordingEnabledNow(enabled));
  }

  async setRecordingEnabledNow(enabled) {
    need(typeof enabled === "boolean", "Invalid activity preference.");
    need(this.readable && this.store, "Clear unreadable local activity before changing its preference.");
    if (this.snapshot.recordingEnabled === enabled) return;
    try {
      const result = await this.store.update((value) => {
        if (!enabled) {
          need(value.recordingPauseCount < MAX_COUNT, "Local activity counter limit reached.");
          value.recordingPauseCount += 1;
        }
        value.recordingEnabled = enabled;
        return { snapshot: value, changed: true };
      });
      this.snapshot = result.snapshot;
      this.issue = null;
    } catch {
      this.pendingFailures = Math.min(MAX_COUNT, this.pendingFailures + 1);
      this.issue = "The recording preference could not be saved; its previous value remains active.";
      throw Error(this.issue);
    }
  }

  clear() {
    return this.enqueue(() => this.clearNow());
  }

  async clearNow() {
    try {
      let store = this.store;
      if (!store) {
        await deleteLocalActivityDatabase();
        store = await openLocalActivityStore();
      }
      const value = await store.reset(
        this.snapshot.recordingEnabled,
        Math.min(MAX_COUNT - 1, this.snapshot.generation + 1),
      );
      this.store = store;
      this.snapshot = value;
      this.readable = true;
      this.pendingFailures = 0;
      this.issue = null;
    } catch {
      this.issue = "Local activity could not be cleared. Pay records were not changed; retry after checking browser storage.";
      throw Error(this.issue);
    }
  }

  refresh() {
    return this.enqueue(() => this.refreshNow());
  }

  async refreshNow() {
    if (!this.store) return;
    try {
      this.snapshot = await this.store.read();
      validateLocalActivity(this.snapshot);
      this.readable = true;
      this.issue = null;
    } catch {
      this.readable = false;
      this.snapshot = emptyLocalActivity(false);
      this.issue = "Local activity could not be read. It has not been overwritten. Clear only this activity to restart it.";
    }
  }

  diagnosticData() {
    return this.enqueue(() => this.diagnosticDataNow());
  }

  diagnosticDataNow() {
    const day = this.now().toISOString().slice(0, 10);
    const exportValue = {
      format: "com.streamentry.linepay.web.local-diagnostics",
      version: 1,
      generatedDayUTC: day,
      firstObservedDayUTC: this.snapshot.firstObservedDayUTC,
      recordingEnabled: this.snapshot.recordingEnabled,
      activityReadable: this.readable,
      recordingIssue:
        this.issue !== null ||
        this.snapshot.failedObservationCount > 0 ||
        this.pendingFailures > 0,
      failedObservationCount:
        this.snapshot.failedObservationCount + this.pendingFailures,
      recordingPauseCount: this.snapshot.recordingPauseCount,
      prunedDayCount: this.snapshot.prunedDayCount,
      totals: MILESTONES.map((milestone) => ({ milestone, count: this.count(milestone) })),
      days: this.snapshot.days,
      scope:
        "Device-local activity totals since this ledger reset, with up to 400 observed UTC days and 20,000 local deduplication digests. Old repeated identities may be counted again after retention. Not App Store installs, global cohorts or subscriber counts. Restored financial records do not backfill history. Disabled recording, failures and retention can make counts incomplete. No pay amounts, payroll dates, names, source text, record identities or deduplication keys are exported. Usage days and counts can still be personal; this is not anonymous and is not a pay-data backup.",
    };
    return JSON.stringify(exportValue, null, 2) + "\n";
  }
}
