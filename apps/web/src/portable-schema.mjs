// Generated from shared/contracts/portable-state/schema-v1.json; offline validation.
export default {
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://linepaycheck.com/contracts/portable-state/schema-v1.json",
  "title": "LinePaycheck portable financial state v1",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "format",
    "version",
    "exportedAtEpochSeconds",
    "source",
    "sourceInventory",
    "identityCrosswalk",
    "activeProfileRef",
    "profiles",
    "ruleSnapshots",
    "ruleChanges",
    "ruleTimelines",
    "periods",
    "workSnapshots",
    "paycheckReceipts",
    "attachments",
    "adoptions"
  ],
  "properties": {
    "format": {
      "const": "com.streamentry.linepay.portable-state"
    },
    "version": {
      "const": 1
    },
    "exportedAtEpochSeconds": {
      "$ref": "#/$defs/epochSeconds"
    },
    "source": {
      "$ref": "#/$defs/source"
    },
    "sourceInventory": {
      "$ref": "#/$defs/sourceInventory"
    },
    "identityCrosswalk": {
      "type": "array",
      "maxItems": 200000,
      "items": {
        "$ref": "#/$defs/identity"
      }
    },
    "profiles": {
      "type": "array",
      "maxItems": 100,
      "items": {
        "$ref": "#/$defs/profile"
      }
    },
    "ruleSnapshots": {
      "type": "array",
      "maxItems": 20000,
      "items": {
        "$ref": "#/$defs/ruleSnapshot"
      }
    },
    "ruleChanges": {
      "type": "array",
      "maxItems": 10000,
      "items": {
        "$ref": "#/$defs/ruleChange"
      }
    },
    "periods": {
      "type": "array",
      "maxItems": 2000,
      "items": {
        "$ref": "#/$defs/period"
      }
    },
    "workSnapshots": {
      "type": "array",
      "maxItems": 20000,
      "items": {
        "$ref": "#/$defs/workSnapshot"
      }
    },
    "paycheckReceipts": {
      "type": "array",
      "maxItems": 10000,
      "items": {
        "$ref": "#/$defs/paycheckReceipt"
      }
    },
    "attachments": {
      "type": "array",
      "maxItems": 512,
      "items": {
        "$ref": "#/$defs/attachment"
      }
    },
    "ruleTimelines": {
      "type": "array",
      "maxItems": 2000,
      "items": {
        "$ref": "#/$defs/ruleTimeline"
      }
    },
    "activeProfileRef": {
      "anyOf": [
        {
          "$ref": "#/$defs/portableID"
        },
        {
          "type": "null"
        }
      ]
    },
    "adoptions": {
      "type": "array",
      "maxItems": 1000,
      "items": {
        "$ref": "#/$defs/profileAdoption"
      }
    }
  },
  "$defs": {
    "portableID": {
      "type": "string",
      "minLength": 1,
      "maxLength": 192,
      "pattern": "^[A-Za-z0-9._:-]+$"
    },
    "localID": {
      "type": "string",
      "minLength": 1,
      "maxLength": 256
    },
    "epochSeconds": {
      "type": "integer",
      "minimum": 946684800,
      "maximum": 4102444799
    },
    "decimal": {
      "type": "string",
      "maxLength": 154,
      "pattern": "^-?(?:0|[1-9][0-9]{0,23})(?:\\.[0-9]{1,128})?$"
    },
    "nonnegativeDecimal": {
      "type": "string",
      "maxLength": 153,
      "pattern": "^(?:0|[1-9][0-9]{0,23})(?:\\.[0-9]{1,128})?$"
    },
    "currency": {
      "type": "string",
      "pattern": "^[A-Z]{3}$"
    },
    "date": {
      "type": "string",
      "pattern": "^20[0-9]{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$"
    },
    "timeZone": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100
    },
    "notRecorded": {
      "type": "array",
      "uniqueItems": true,
      "items": {
        "type": "string",
        "minLength": 1,
        "maxLength": 100
      }
    },
    "source": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "client",
        "localStateSchema",
        "exporterVersion"
      ],
      "properties": {
        "client": {
          "enum": [
            "ios",
            "android",
            "web"
          ]
        },
        "localStateSchema": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        },
        "exporterVersion": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        }
      }
    },
    "sourceInventory": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "profileCount",
        "ruleSnapshotCount",
        "ruleChangeCount",
        "ruleTimelineCount",
        "periodCount",
        "workSnapshotCount",
        "workEntryCount",
        "paycheckReceiptCount",
        "attachmentCount",
        "unsupportedFinancialRecordKinds",
        "unsupportedDraftKinds",
        "omittedFinancialRecordCount",
        "workBreakCount",
        "workCorrectionCount",
        "calculationComponentCount",
        "auditRevisionCount",
        "workweekCount",
        "weeklyAllocationCount",
        "periodWindowCount",
        "adoptionCount"
      ],
      "properties": {
        "profileCount": {
          "type": "integer",
          "minimum": 0
        },
        "ruleSnapshotCount": {
          "type": "integer",
          "minimum": 0
        },
        "ruleChangeCount": {
          "type": "integer",
          "minimum": 0
        },
        "periodCount": {
          "type": "integer",
          "minimum": 0
        },
        "workSnapshotCount": {
          "type": "integer",
          "minimum": 0
        },
        "workEntryCount": {
          "type": "integer",
          "minimum": 0
        },
        "paycheckReceiptCount": {
          "type": "integer",
          "minimum": 0
        },
        "attachmentCount": {
          "type": "integer",
          "minimum": 0
        },
        "unsupportedFinancialRecordKinds": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 100
          }
        },
        "unsupportedDraftKinds": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "type": "string",
            "minLength": 1,
            "maxLength": 100
          }
        },
        "omittedFinancialRecordCount": {
          "const": 0
        },
        "ruleTimelineCount": {
          "type": "integer",
          "minimum": 0
        },
        "workBreakCount": {
          "type": "integer",
          "minimum": 0
        },
        "workCorrectionCount": {
          "type": "integer",
          "minimum": 0
        },
        "calculationComponentCount": {
          "type": "integer",
          "minimum": 0
        },
        "auditRevisionCount": {
          "type": "integer",
          "minimum": 0
        },
        "workweekCount": {
          "type": "integer",
          "minimum": 0
        },
        "weeklyAllocationCount": {
          "type": "integer",
          "minimum": 0
        },
        "periodWindowCount": {
          "type": "integer",
          "minimum": 0
        },
        "adoptionCount": {
          "type": "integer",
          "minimum": 0
        }
      }
    },
    "identity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "entityType",
        "portableID",
        "originClient",
        "originKind",
        "originLocalID"
      ],
      "properties": {
        "entityType": {
          "enum": [
            "profile",
            "ruleSnapshot",
            "ruleChange",
            "period",
            "workSnapshot",
            "workEntry",
            "workBreak",
            "workCorrection",
            "paycheckReceipt",
            "calculationComponent",
            "attachment",
            "paystub",
            "periodWindow",
            "calloutEvent",
            "ruleTimeline",
            "auditRevision",
            "workweek",
            "weeklyAllocation",
            "profileAdoption"
          ]
        },
        "portableID": {
          "$ref": "#/$defs/portableID"
        },
        "originClient": {
          "enum": [
            "ios",
            "android",
            "web"
          ]
        },
        "originKind": {
          "enum": [
            "native",
            "derived"
          ]
        },
        "originLocalID": {
          "anyOf": [
            {
              "$ref": "#/$defs/localID"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "profile": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "timeZone",
        "cadence",
        "cycleStartDate",
        "customEndDate",
        "ruleRef",
        "baselineRuleRef",
        "ruleChangeRefs",
        "currentPeriodRef",
        "currentWorkSnapshotRef",
        "fieldsNotRecorded",
        "adoptedFromProfileRef"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "name": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 200
            },
            {
              "type": "null"
            }
          ]
        },
        "timeZone": {
          "anyOf": [
            {
              "$ref": "#/$defs/timeZone"
            },
            {
              "type": "null"
            }
          ]
        },
        "cadence": {
          "anyOf": [
            {
              "enum": [
                "weekly",
                "biweekly",
                "semimonthly",
                "custom",
                "manual"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "cycleStartDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "customEndDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleRef": {
          "$ref": "#/$defs/portableID"
        },
        "baselineRuleRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleChangeRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "currentPeriodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "currentWorkSnapshotRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "adoptedFromProfileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "rounding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "scope",
        "scale",
        "mode"
      ],
      "properties": {
        "scope": {
          "enum": [
            "payCategory",
            "legacySegments"
          ]
        },
        "scale": {
          "type": "integer",
          "minimum": 0,
          "maximum": 8
        },
        "mode": {
          "enum": [
            "halfUp",
            "halfEven",
            "down",
            "up",
            "towardZero",
            "awayFromZero",
            "bankers"
          ]
        }
      }
    },
    "sourceLocator": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "title",
        "url",
        "section",
        "verifiedEpochSeconds",
        "ruleKey",
        "documentRef",
        "documentSHA256",
        "documentPage",
        "quotedText"
      ],
      "properties": {
        "title": {
          "type": "string",
          "minLength": 1,
          "maxLength": 300
        },
        "url": {
          "type": "string",
          "maxLength": 2048
        },
        "section": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "verifiedEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleKey": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "documentRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "documentSHA256": {
          "anyOf": [
            {
              "$ref": "#/$defs/sha256"
            },
            {
              "type": "null"
            }
          ]
        },
        "documentPage": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0
            },
            {
              "type": "null"
            }
          ]
        },
        "quotedText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 10000
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "sha256": {
      "type": "string",
      "pattern": "^[0-9a-f]{64}$"
    },
    "scheduleWindow": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "weekday",
        "start",
        "end"
      ],
      "properties": {
        "weekday": {
          "enum": [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday"
          ]
        },
        "start": {
          "type": "string",
          "pattern": "^(?:[01][0-9]|2[0-3]):[0-5][0-9]$"
        },
        "end": {
          "type": "string",
          "pattern": "^(?:[01][0-9]|2[0-3]):[0-5][0-9]$"
        }
      }
    },
    "datePremium": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "date",
        "multiplier"
      ],
      "properties": {
        "date": {
          "$ref": "#/$defs/date"
        },
        "multiplier": {
          "$ref": "#/$defs/nonnegativeDecimal"
        }
      }
    },
    "weekdayPremium": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "weekday",
        "multiplier"
      ],
      "properties": {
        "weekday": {
          "enum": [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday"
          ]
        },
        "multiplier": {
          "$ref": "#/$defs/nonnegativeDecimal"
        }
      }
    },
    "dailyTier": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "afterHours",
        "multiplier"
      ],
      "properties": {
        "afterHours": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "multiplier": {
          "$ref": "#/$defs/nonnegativeDecimal"
        }
      }
    },
    "weeklyRule": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "workweekStart",
        "thresholdHours",
        "applicability"
      ],
      "properties": {
        "workweekStart": {
          "enum": [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday"
          ]
        },
        "thresholdHours": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "applicability": {
          "enum": [
            "unknown",
            "coveredNonexemptHourly",
            "unsupported"
          ]
        }
      }
    },
    "ruleSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "ruleID",
        "version",
        "displayName",
        "effectiveStartDate",
        "effectiveEndDateInclusive",
        "currency",
        "hourlyRate",
        "regularSchedule",
        "dailyOvertimeTiers",
        "outsideScheduleMultiplier",
        "weekdayPremiums",
        "datePremiums",
        "calloutMinimumHours",
        "perDiemPerWorkDate",
        "weeklyOvertime",
        "rounding",
        "sources",
        "unsupportedRuleNotes",
        "confirmedAtEpochSeconds",
        "fieldsNotRecorded",
        "confirmedByWorker"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "ruleID": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "version": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128
        },
        "displayName": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 300
            },
            {
              "type": "null"
            }
          ]
        },
        "effectiveStartDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectiveEndDateInclusive": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "currency": {
          "$ref": "#/$defs/currency"
        },
        "hourlyRate": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "regularSchedule": {
          "anyOf": [
            {
              "type": "array",
              "maxItems": 64,
              "items": {
                "$ref": "#/$defs/scheduleWindow"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "dailyOvertimeTiers": {
          "anyOf": [
            {
              "type": "array",
              "maxItems": 32,
              "items": {
                "$ref": "#/$defs/dailyTier"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "outsideScheduleMultiplier": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "weekdayPremiums": {
          "anyOf": [
            {
              "type": "array",
              "maxItems": 7,
              "items": {
                "$ref": "#/$defs/weekdayPremium"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "datePremiums": {
          "anyOf": [
            {
              "type": "array",
              "maxItems": 10000,
              "items": {
                "$ref": "#/$defs/datePremium"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "calloutMinimumHours": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "perDiemPerWorkDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "weeklyOvertime": {
          "anyOf": [
            {
              "$ref": "#/$defs/weeklyRule"
            },
            {
              "type": "null"
            }
          ]
        },
        "rounding": {
          "anyOf": [
            {
              "$ref": "#/$defs/rounding"
            },
            {
              "type": "null"
            }
          ]
        },
        "sources": {
          "anyOf": [
            {
              "type": "array",
              "maxItems": 256,
              "items": {
                "$ref": "#/$defs/sourceLocator"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "unsupportedRuleNotes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4000
            },
            {
              "type": "null"
            }
          ]
        },
        "confirmedAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "confirmedByWorker": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "ruleChange": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "profileRef",
        "periodRef",
        "effectiveDate",
        "sourceProfileRef",
        "ruleRef",
        "confirmed",
        "createdAtEpochSeconds",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "periodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "effectiveDate": {
          "$ref": "#/$defs/date"
        },
        "sourceProfileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleRef": {
          "$ref": "#/$defs/portableID"
        },
        "confirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "calendarWindow": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "startDate",
        "endDateInclusive",
        "endExclusiveDate",
        "timeZone",
        "boundaryModel",
        "startEpochSeconds",
        "endExclusiveEpochSeconds",
        "fieldsNotRecorded"
      ],
      "properties": {
        "startDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "endDateInclusive": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "endExclusiveDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "timeZone": {
          "anyOf": [
            {
              "$ref": "#/$defs/timeZone"
            },
            {
              "type": "null"
            }
          ]
        },
        "boundaryModel": {
          "enum": [
            "exactInstants",
            "localDatesOnly",
            "sourcePeriodUnknown"
          ]
        },
        "startEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "endExclusiveEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "period": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "profileRef",
        "calendarWindow",
        "cadence",
        "isCurrent",
        "closed",
        "archivedAtEpochSeconds",
        "calculationIssue",
        "ruleRef",
        "ruleChangeRefs",
        "currentWorkSnapshotRef",
        "workSnapshotRefs",
        "workCorrections",
        "fieldsNotRecorded",
        "windowRef",
        "ruleTimelineRefs",
        "calculation",
        "auditCompletedAtEpochSeconds",
        "workRevision"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "profileRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "calendarWindow": {
          "$ref": "#/$defs/calendarWindow"
        },
        "cadence": {
          "anyOf": [
            {
              "enum": [
                "weekly",
                "biweekly",
                "semimonthly",
                "custom",
                "manual"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "isCurrent": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "closed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "archivedAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "calculationIssue": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4000
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleChangeRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "currentWorkSnapshotRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "workSnapshotRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "workCorrections": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/workCorrection"
          }
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "windowRef": {
          "$ref": "#/$defs/portableID"
        },
        "ruleTimelineRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/portableID"
          },
          "uniqueItems": true
        },
        "calculation": {
          "anyOf": [
            {
              "$ref": "#/$defs/calculation"
            },
            {
              "type": "null"
            }
          ]
        },
        "auditCompletedAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "workRevision": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "workCorrection": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "workSnapshotRef",
        "reason",
        "correctedAtEpochSeconds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "workSnapshotRef": {
          "$ref": "#/$defs/portableID"
        },
        "reason": {
          "type": "string",
          "maxLength": 2000
        },
        "correctedAtEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        }
      }
    },
    "workSnapshot": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "profileRef",
        "periodRef",
        "role",
        "revision",
        "sourceRef",
        "work",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "profileRef": {
          "$ref": "#/$defs/portableID"
        },
        "periodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "role": {
          "enum": [
            "currentLedger",
            "periodRevision",
            "paycheckInput",
            "auditRevision",
            "workCorrection"
          ]
        },
        "revision": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 1000000
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "work": {
          "type": "array",
          "maxItems": 50000,
          "items": {
            "$ref": "#/$defs/workEntry"
          }
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "workEntry": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "startEpochSeconds",
        "endEpochSeconds",
        "timeZone",
        "kind",
        "calloutEventRef",
        "unpaidBreaks",
        "note",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "startEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        },
        "endEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        },
        "timeZone": {
          "$ref": "#/$defs/timeZone"
        },
        "kind": {
          "enum": [
            "regular",
            "callout",
            "other"
          ]
        },
        "calloutEventRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "unpaidBreaks": {
          "type": "array",
          "maxItems": 100,
          "items": {
            "$ref": "#/$defs/workBreak"
          }
        },
        "note": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4000
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "workBreak": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "startEpochSeconds",
        "endEpochSeconds"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "startEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        },
        "endEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        }
      }
    },
    "money": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "amount",
        "currency"
      ],
      "properties": {
        "amount": {
          "$ref": "#/$defs/decimal"
        },
        "currency": {
          "$ref": "#/$defs/currency"
        }
      }
    },
    "paycheckReceipt": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "receiptKind",
        "id",
        "periodRef",
        "workSnapshotRef",
        "createdAtEpochSeconds",
        "supersedesReceiptRef",
        "producer",
        "ruleRefs",
        "sourcePeriod",
        "paystubFacts",
        "lineFacts",
        "reviewFacts",
        "calculation",
        "assessment",
        "reconciliation",
        "attachmentRefs",
        "fieldsNotRecorded",
        "auditRevisionRef",
        "targetWindowRef",
        "targetWindow",
        "targetCadence",
        "targetRuleChangeRefs"
      ],
      "properties": {
        "receiptKind": {
          "const": "paycheck-v1"
        },
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "periodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "workSnapshotRef": {
          "$ref": "#/$defs/portableID"
        },
        "createdAtEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        },
        "supersedesReceiptRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "producer": {
          "$ref": "#/$defs/producer"
        },
        "ruleRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "sourcePeriod": {
          "anyOf": [
            {
              "$ref": "#/$defs/sourcePeriod"
            },
            {
              "type": "null"
            }
          ]
        },
        "paystubFacts": {
          "$ref": "#/$defs/paystubFacts"
        },
        "lineFacts": {
          "$ref": "#/$defs/lineFacts"
        },
        "reviewFacts": {
          "$ref": "#/$defs/reviewFacts"
        },
        "calculation": {
          "anyOf": [
            {
              "$ref": "#/$defs/calculation"
            },
            {
              "type": "null"
            }
          ]
        },
        "assessment": {
          "$ref": "#/$defs/assessment"
        },
        "reconciliation": {
          "anyOf": [
            {
              "$ref": "#/$defs/reconciliation"
            },
            {
              "type": "null"
            }
          ]
        },
        "attachmentRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "auditRevisionRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "targetWindowRef": {
          "$ref": "#/$defs/portableID"
        },
        "targetWindow": {
          "$ref": "#/$defs/calendarWindow"
        },
        "targetCadence": {
          "anyOf": [
            {
              "enum": [
                "weekly",
                "biweekly",
                "semimonthly",
                "custom",
                "manual"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "targetRuleChangeRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        }
      }
    },
    "producer": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "client",
        "localStateSchema",
        "calculationEngineID",
        "calculationEngineVersion",
        "assessmentEngineID",
        "assessmentEngineVersion",
        "fieldsNotRecorded"
      ],
      "properties": {
        "client": {
          "enum": [
            "ios",
            "android",
            "web"
          ]
        },
        "localStateSchema": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1,
              "maximum": 1000
            },
            {
              "type": "null"
            }
          ]
        },
        "calculationEngineID": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 160
            },
            {
              "type": "null"
            }
          ]
        },
        "calculationEngineVersion": {
          "anyOf": [
            {
              "type": [
                "string",
                "integer"
              ],
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "assessmentEngineID": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 160
            },
            {
              "type": "null"
            }
          ]
        },
        "assessmentEngineVersion": {
          "anyOf": [
            {
              "type": [
                "string",
                "integer"
              ],
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "paystubFacts": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "periodStartDate",
        "periodEndDateInclusive",
        "currency",
        "grossPay",
        "regularHours",
        "regularPay",
        "overtimeHours",
        "overtimePay",
        "doubleTimeHours",
        "doubleTimePay",
        "calloutPay",
        "perDiemPay",
        "notes",
        "confirmedAtEpochSeconds",
        "evidenceRef",
        "fieldsNotRecorded",
        "confirmed"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "periodStartDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "periodEndDateInclusive": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "currency": {
          "$ref": "#/$defs/currency"
        },
        "grossPay": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "regularHours": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "regularPay": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "overtimeHours": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "overtimePay": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "doubleTimeHours": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "doubleTimePay": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "calloutPay": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "perDiemPay": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "notes": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 4000
            },
            {
              "type": "null"
            }
          ]
        },
        "confirmedAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidenceRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "confirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "lineFacts": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "grossBasis",
        "lineLayout",
        "hoursBasis",
        "guaranteeLayout",
        "amounts",
        "hours",
        "reviewedFields",
        "suggestions",
        "hasAdditionalUnmappedPay",
        "workComplete",
        "earningsLinesComplete",
        "fieldsNotRecorded"
      ],
      "properties": {
        "grossBasis": {
          "anyOf": [
            {
              "enum": [
                "unconfirmed",
                "wagesOnly",
                "wagesAndPerDiem"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "lineLayout": {
          "anyOf": [
            {
              "enum": [
                "unconfirmed",
                "fullRateBuckets",
                "basePlusPremium"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "hoursBasis": {
          "anyOf": [
            {
              "enum": [
                "unconfirmed",
                "actualWork",
                "paidEquivalents"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "guaranteeLayout": {
          "anyOf": [
            {
              "enum": [
                "unconfirmed",
                "separateLine",
                "includedInHourlyLines"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "amounts": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "$ref": "#/$defs/lineAmount"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "hours": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "$ref": "#/$defs/lineHours"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "reviewedFields": {
          "anyOf": [
            {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "maxLength": 80
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "suggestions": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "$ref": "#/$defs/ocrSuggestion"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "hasAdditionalUnmappedPay": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "workComplete": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "earningsLinesComplete": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "lineAmount": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "field",
        "amount"
      ],
      "properties": {
        "field": {
          "type": "string",
          "maxLength": 80
        },
        "amount": {
          "$ref": "#/$defs/money"
        }
      }
    },
    "lineHours": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "field",
        "hours"
      ],
      "properties": {
        "field": {
          "type": "string",
          "maxLength": 80
        },
        "hours": {
          "$ref": "#/$defs/nonnegativeDecimal"
        }
      }
    },
    "ocrSuggestion": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "field",
        "value",
        "sourceText",
        "region",
        "confidence",
        "reason"
      ],
      "properties": {
        "field": {
          "type": "string",
          "maxLength": 80
        },
        "value": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 512
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceText": {
          "type": "string",
          "maxLength": 4000
        },
        "region": {
          "anyOf": [
            {
              "$ref": "#/$defs/sourceRegion"
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "$ref": "#/$defs/sourceScalar"
        },
        "reason": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 2000
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "sourceRegion": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x",
        "y",
        "width",
        "height",
        "page"
      ],
      "properties": {
        "x": {
          "$ref": "#/$defs/sourceScalar"
        },
        "y": {
          "$ref": "#/$defs/sourceScalar"
        },
        "width": {
          "$ref": "#/$defs/sourceScalar"
        },
        "height": {
          "$ref": "#/$defs/sourceScalar"
        },
        "page": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 10000
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "reviewFacts": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "completeWorkConfirmed",
        "ruleCoverageConfirmed",
        "unreviewedFields",
        "weeklyReviewPending",
        "fieldsNotRecorded"
      ],
      "properties": {
        "completeWorkConfirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleCoverageConfirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "unreviewedFields": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "weeklyReviewPending": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "calculation": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "agreementID",
        "agreementVersion",
        "primaryRuleRef",
        "agreementSnapshotRefs",
        "currency",
        "total",
        "provenance",
        "weeklyRegularRate",
        "components",
        "fieldsNotRecorded",
        "engine",
        "coverage",
        "wages",
        "allowances",
        "ruleTimelineRef",
        "ruleChangeRefs"
      ],
      "properties": {
        "agreementID": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "agreementVersion": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "primaryRuleRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "agreementSnapshotRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "currency": {
          "$ref": "#/$defs/currency"
        },
        "total": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "provenance": {
          "anyOf": [
            {
              "$ref": "#/$defs/calculationProvenance"
            },
            {
              "type": "null"
            }
          ]
        },
        "weeklyRegularRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/weeklyResult"
            },
            {
              "type": "null"
            }
          ]
        },
        "components": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/component"
          }
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "engine": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 160
            },
            {
              "type": "null"
            }
          ]
        },
        "coverage": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 160
            },
            {
              "type": "null"
            }
          ]
        },
        "wages": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "allowances": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleTimelineRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleChangeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/portableID"
          },
          "uniqueItems": true
        }
      }
    },
    "calculationProvenance": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "engine",
        "rounding",
        "callout"
      ],
      "properties": {
        "engine": {
          "type": "string",
          "maxLength": 160
        },
        "rounding": {
          "type": "string",
          "maxLength": 160
        },
        "callout": {
          "type": "string",
          "maxLength": 160
        }
      }
    },
    "component": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "category",
        "workRef",
        "localDate",
        "hours",
        "workedSeconds",
        "multiplier",
        "amount",
        "explanation",
        "ruleKeys",
        "baseRate",
        "appliedAgreement",
        "unroundedAmount",
        "baseTimeNumerator",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "category": {
          "enum": [
            "workedHours",
            "calloutGuarantee",
            "perDiem"
          ]
        },
        "workRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "localDate": {
          "$ref": "#/$defs/date"
        },
        "hours": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "workedSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "multiplier": {
          "anyOf": [
            {
              "$ref": "#/$defs/nonnegativeDecimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "amount": {
          "$ref": "#/$defs/money"
        },
        "explanation": {
          "type": "string",
          "maxLength": 2000
        },
        "ruleKeys": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 100
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "baseRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "appliedAgreement": {
          "anyOf": [
            {
              "$ref": "#/$defs/agreementReference"
            },
            {
              "type": "null"
            }
          ]
        },
        "unroundedAmount": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "baseTimeNumerator": {
          "anyOf": [
            {
              "$ref": "#/$defs/decimal"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "agreementReference": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "ruleRef",
        "ruleID",
        "version",
        "hourlyRate"
      ],
      "properties": {
        "ruleRef": {
          "$ref": "#/$defs/portableID"
        },
        "ruleID": {
          "type": "string",
          "maxLength": 128
        },
        "version": {
          "type": "string",
          "maxLength": 128
        },
        "hourlyRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "weeklyResult": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "workweekID",
        "weekStart",
        "workweekStart",
        "qualifyingHours",
        "includableRemuneration",
        "regularRate",
        "overtimeHours",
        "statutoryAdditionalPremium",
        "eligibleExtraPremiumCredit",
        "remainingAdditionalPremium",
        "cashRemuneration",
        "expectedCash",
        "allocations",
        "engineVersion",
        "startEpochSeconds",
        "endEpochSeconds",
        "timeZone",
        "fieldsNotRecorded"
      ],
      "properties": {
        "workweekID": {
          "$ref": "#/$defs/portableID"
        },
        "weekStart": {
          "$ref": "#/$defs/date"
        },
        "workweekStart": {
          "enum": [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday"
          ]
        },
        "qualifyingHours": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "includableRemuneration": {
          "$ref": "#/$defs/money"
        },
        "regularRate": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "overtimeHours": {
          "$ref": "#/$defs/nonnegativeDecimal"
        },
        "statutoryAdditionalPremium": {
          "$ref": "#/$defs/money"
        },
        "eligibleExtraPremiumCredit": {
          "$ref": "#/$defs/money"
        },
        "remainingAdditionalPremium": {
          "$ref": "#/$defs/money"
        },
        "cashRemuneration": {
          "$ref": "#/$defs/money"
        },
        "expectedCash": {
          "$ref": "#/$defs/money"
        },
        "allocations": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/weeklyAllocation"
          }
        },
        "engineVersion": {
          "type": "string",
          "maxLength": 160
        },
        "startEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "endEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "timeZone": {
          "anyOf": [
            {
              "$ref": "#/$defs/timeZone"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "weeklyAllocation": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "periodRef",
        "amount",
        "basis"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "periodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "amount": {
          "$ref": "#/$defs/money"
        },
        "basis": {
          "$ref": "#/$defs/money"
        }
      }
    },
    "assessment": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "engineID",
        "engineVersion",
        "verdict",
        "scope",
        "expectedGross",
        "paidGross",
        "difference",
        "comparisons",
        "reviewReasons",
        "scopeNotes",
        "weeklyContextCount",
        "weeklyReviewRefs",
        "fieldsNotRecorded",
        "periodMatch",
        "reportedPeriod"
      ],
      "properties": {
        "engineID": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 160
            },
            {
              "type": "null"
            }
          ]
        },
        "engineVersion": {
          "anyOf": [
            {
              "type": [
                "string",
                "integer"
              ],
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "verdict": {
          "enum": [
            "matches",
            "possibleShortfall",
            "possibleOverpayment",
            "needsReview",
            "notComparable"
          ]
        },
        "scope": {
          "enum": [
            "grossOnly",
            "confirmedLines"
          ]
        },
        "expectedGross": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "paidGross": {
          "$ref": "#/$defs/money"
        },
        "difference": {
          "anyOf": [
            {
              "$ref": "#/$defs/money"
            },
            {
              "type": "null"
            }
          ]
        },
        "comparisons": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/comparison"
          }
        },
        "reviewReasons": {
          "type": "array",
          "items": {
            "type": "string",
            "maxLength": 4000
          }
        },
        "scopeNotes": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "type": "string",
                "maxLength": 4000
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "weeklyContextCount": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 128
            },
            {
              "type": "null"
            }
          ]
        },
        "weeklyReviewRefs": {
          "anyOf": [
            {
              "type": "array",
              "items": {
                "$ref": "#/$defs/portableID"
              }
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        },
        "periodMatch": {
          "anyOf": [
            {
              "enum": [
                "confirmedSamePeriod",
                "differentPeriod",
                "unconfirmedPeriod"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "reportedPeriod": {
          "anyOf": [
            {
              "$ref": "#/$defs/sourcePeriod"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "comparison": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "field",
        "expected",
        "paid",
        "difference",
        "unit",
        "currency",
        "componentRefs"
      ],
      "properties": {
        "id": {
          "type": "string",
          "maxLength": 100
        },
        "field": {
          "enum": [
            "grossPay",
            "regularHours",
            "regularPay",
            "overtimeHours",
            "overtimePay",
            "doubleTimeHours",
            "doubleTimePay",
            "calloutPay",
            "perDiemPay"
          ]
        },
        "expected": {
          "$ref": "#/$defs/decimal"
        },
        "paid": {
          "$ref": "#/$defs/decimal"
        },
        "difference": {
          "$ref": "#/$defs/decimal"
        },
        "unit": {
          "enum": [
            "money",
            "hours"
          ]
        },
        "currency": {
          "$ref": "#/$defs/currency"
        },
        "componentRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        }
      }
    },
    "reconciliation": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "expectedGross",
        "actualGross",
        "difference",
        "direction"
      ],
      "properties": {
        "expectedGross": {
          "$ref": "#/$defs/money"
        },
        "actualGross": {
          "$ref": "#/$defs/money"
        },
        "difference": {
          "$ref": "#/$defs/money"
        },
        "direction": {
          "enum": [
            "matches",
            "possibleUnderpayment",
            "possibleOverpayment"
          ]
        }
      }
    },
    "attachment": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "kind",
        "originalFilename",
        "mediaType",
        "sourceKind",
        "createdAtEpochSeconds",
        "recognizedText",
        "sha256",
        "byteLength",
        "bytesBase64",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "kind": {
          "enum": [
            "paystubOriginal",
            "sourceDocumentOriginal"
          ]
        },
        "originalFilename": {
          "type": "string",
          "minLength": 1,
          "maxLength": 255
        },
        "mediaType": {
          "type": "string",
          "pattern": "^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$"
        },
        "sourceKind": {
          "anyOf": [
            {
              "enum": [
                "scan",
                "photo",
                "file",
                "manual"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "createdAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "recognizedText": {
          "anyOf": [
            {
              "type": "string",
              "maxLength": 200000
            },
            {
              "type": "null"
            }
          ]
        },
        "sha256": {
          "$ref": "#/$defs/sha256"
        },
        "byteLength": {
          "type": "integer",
          "minimum": 1,
          "maximum": 26214400
        },
        "bytesBase64": {
          "type": "string",
          "minLength": 4,
          "contentEncoding": "base64"
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "ruleTimeline": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "periodRef",
        "baselineRuleRef",
        "ruleChangeRefs",
        "createdAtEpochSeconds",
        "confirmed",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "periodRef": {
          "$ref": "#/$defs/portableID"
        },
        "baselineRuleRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "ruleChangeRefs": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/portableID"
          },
          "uniqueItems": true
        },
        "createdAtEpochSeconds": {
          "anyOf": [
            {
              "$ref": "#/$defs/epochSeconds"
            },
            {
              "type": "null"
            }
          ]
        },
        "confirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "sourcePeriod": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "startDate",
        "endDateInclusive",
        "timeZone",
        "confirmed",
        "fieldsNotRecorded"
      ],
      "properties": {
        "startDate": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "endDateInclusive": {
          "anyOf": [
            {
              "$ref": "#/$defs/date"
            },
            {
              "type": "null"
            }
          ]
        },
        "timeZone": {
          "anyOf": [
            {
              "$ref": "#/$defs/timeZone"
            },
            {
              "type": "null"
            }
          ]
        },
        "confirmed": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "sourceScalar": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^-?(?:0|[1-9][0-9]{0,24})(?:\\.[0-9]{1,40})?(?:[eE][+-]?[0-9]{1,3})?$"
    },
    "profileAdoption": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "sourceProfileRef",
        "adoptedProfileRef",
        "sourcePeriodRef",
        "adoptedPeriodRef",
        "sourceWorkSnapshotRef",
        "adoptedWorkSnapshotRef",
        "sourceRuleRefs",
        "adoptedRuleRefs",
        "confirmedAtEpochSeconds",
        "confirmedFields",
        "fieldsNotRecorded"
      ],
      "properties": {
        "id": {
          "$ref": "#/$defs/portableID"
        },
        "sourceProfileRef": {
          "$ref": "#/$defs/portableID"
        },
        "adoptedProfileRef": {
          "$ref": "#/$defs/portableID"
        },
        "sourcePeriodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "adoptedPeriodRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceWorkSnapshotRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "adoptedWorkSnapshotRef": {
          "anyOf": [
            {
              "$ref": "#/$defs/portableID"
            },
            {
              "type": "null"
            }
          ]
        },
        "sourceRuleRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "adoptedRuleRefs": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/portableID"
          }
        },
        "confirmedAtEpochSeconds": {
          "$ref": "#/$defs/epochSeconds"
        },
        "confirmedFields": {
          "type": "array",
          "minItems": 1,
          "maxItems": 64,
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/confirmedField"
          }
        },
        "fieldsNotRecorded": {
          "$ref": "#/$defs/notRecorded"
        }
      }
    },
    "confirmedField": {
      "type": "string",
      "enum": [
        "name",
        "timeZone",
        "cadence",
        "cycleStartDate",
        "customEndDate",
        "currency",
        "hourlyRate",
        "regularSchedule",
        "dailyOvertimeTiers",
        "outsideScheduleMultiplier",
        "weekdayPremiums",
        "datePremiums",
        "calloutMinimumHours",
        "perDiemPerWorkDate",
        "effectiveStartDate",
        "effectiveEndDateInclusive",
        "rounding",
        "weeklyOvertimeThreshold",
        "workweekStart",
        "currentWork",
        "periodWindow"
      ]
    }
  }
};
