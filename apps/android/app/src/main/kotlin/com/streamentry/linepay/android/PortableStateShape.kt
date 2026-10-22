package com.streamentry.linepay.android

import com.google.gson.JsonElement
import com.google.gson.JsonObject

/** Closed, version-specific structural validators for the shared portable-state v1 contract. */
internal object PortableStateShape {
    fun validateDocument(value: JsonElement, path: String = "document") {
        fields(value, path, setOf("format", "version", "exportedAtEpochSeconds", "source", "sourceInventory", "identityCrosswalk", "activeProfileRef", "profiles", "ruleSnapshots", "ruleChanges", "ruleTimelines", "periods", "workSnapshots", "paycheckReceipts", "attachments", "adoptions"))
        require(value.asJsonObject.get("format") == com.google.gson.JsonParser.parseString("\"com.streamentry.linepay.portable-state\"")) { path + ".format" + " has an unsupported value." }
        require(value.asJsonObject.get("version") == com.google.gson.JsonParser.parseString("1")) { path + ".version" + " has an unsupported value." }
        validateEpochSeconds(value.asJsonObject.get("exportedAtEpochSeconds"), path + ".exportedAtEpochSeconds")
        validateSource(value.asJsonObject.get("source"), path + ".source")
        validateSourceInventory(value.asJsonObject.get("sourceInventory"), path + ".sourceInventory")
        array(value.asJsonObject.get("identityCrosswalk"), path + ".identityCrosswalk", 0, 200000, false)
        value.asJsonObject.get("identityCrosswalk").asJsonArray.forEach { item ->
            validateIdentity(item, path + ".identityCrosswalk" + "[]")
        }
        array(value.asJsonObject.get("profiles"), path + ".profiles", 0, 100, false)
        value.asJsonObject.get("profiles").asJsonArray.forEach { item ->
            validateProfile(item, path + ".profiles" + "[]")
        }
        array(value.asJsonObject.get("ruleSnapshots"), path + ".ruleSnapshots", 0, 20000, false)
        value.asJsonObject.get("ruleSnapshots").asJsonArray.forEach { item ->
            validateRuleSnapshot(item, path + ".ruleSnapshots" + "[]")
        }
        array(value.asJsonObject.get("ruleChanges"), path + ".ruleChanges", 0, 10000, false)
        value.asJsonObject.get("ruleChanges").asJsonArray.forEach { item ->
            validateRuleChange(item, path + ".ruleChanges" + "[]")
        }
        array(value.asJsonObject.get("periods"), path + ".periods", 0, 2000, false)
        value.asJsonObject.get("periods").asJsonArray.forEach { item ->
            validatePeriod(item, path + ".periods" + "[]")
        }
        array(value.asJsonObject.get("workSnapshots"), path + ".workSnapshots", 0, 20000, false)
        value.asJsonObject.get("workSnapshots").asJsonArray.forEach { item ->
            validateWorkSnapshot(item, path + ".workSnapshots" + "[]")
        }
        array(value.asJsonObject.get("paycheckReceipts"), path + ".paycheckReceipts", 0, 10000, false)
        value.asJsonObject.get("paycheckReceipts").asJsonArray.forEach { item ->
            validatePaycheckReceipt(item, path + ".paycheckReceipts" + "[]")
        }
        array(value.asJsonObject.get("attachments"), path + ".attachments", 0, 512, false)
        value.asJsonObject.get("attachments").asJsonArray.forEach { item ->
            validateAttachment(item, path + ".attachments" + "[]")
        }
        array(value.asJsonObject.get("ruleTimelines"), path + ".ruleTimelines", 0, 2000, false)
        value.asJsonObject.get("ruleTimelines").asJsonArray.forEach { item ->
            validateRuleTimeline(item, path + ".ruleTimelines" + "[]")
        }
        if (!value.asJsonObject.get("activeProfileRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("activeProfileRef"), path + ".activeProfileRef")
        }
        array(value.asJsonObject.get("adoptions"), path + ".adoptions", 0, 1000, false)
        value.asJsonObject.get("adoptions").asJsonArray.forEach { item ->
            validateProfileAdoption(item, path + ".adoptions" + "[]")
        }
    }

    fun validatePortableID(value: JsonElement, path: String = "portableID") {
        text(value, path, 1, 192)
        require(Regex("^[A-Za-z0-9._:-]+\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateLocalID(value: JsonElement, path: String = "localID") {
        text(value, path, 1, 256)
    }

    fun validateEpochSeconds(value: JsonElement, path: String = "epochSeconds") {
        integer(value, path, "946684800", "4102444799")
    }

    fun validateDecimal(value: JsonElement, path: String = "decimal") {
        text(value, path, 0, 154)
        require(Regex("^-?(?:0|[1-9][0-9]{0,23})(?:\\.[0-9]{1,128})?\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateNonnegativeDecimal(value: JsonElement, path: String = "nonnegativeDecimal") {
        text(value, path, 0, 153)
        require(Regex("^(?:0|[1-9][0-9]{0,23})(?:\\.[0-9]{1,128})?\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateCurrency(value: JsonElement, path: String = "currency") {
        text(value, path, 0, 100000000)
        require(Regex("^[A-Z]{3}\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateDate(value: JsonElement, path: String = "date") {
        text(value, path, 0, 100000000)
        require(Regex("^20[0-9]{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])\$").matches(value.asString)) { path + " has invalid text." }
        require(runCatching { java.time.LocalDate.parse(value.asString) }.isSuccess) { path + ": invalid calendar date." }
    }

    fun validateTimeZone(value: JsonElement, path: String = "timeZone") {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isString && value.asString in canonicalTimeZones) { path + " has an unsupported value." }
        text(value, path, 1, 100)
        require(value.asString in java.time.ZoneId.getAvailableZoneIds()) { path + ": portable v1 needs a supported IANA time zone." }
    }

    fun validateNotRecorded(value: JsonElement, path: String = "notRecorded") {
        array(value, path, 0, 100000, true)
        value.asJsonArray.forEach { item ->
            text(item, path + "[]", 1, 100)
        }
    }

    fun validateSource(value: JsonElement, path: String = "source") {
        fields(value, path, setOf("client", "localStateSchema", "exporterVersion"))
        require(value.asJsonObject.get("client").isJsonPrimitive && value.asJsonObject.get("client").asJsonPrimitive.isString && value.asJsonObject.get("client").asString in setOf("ios", "android", "web")) { path + ".client" + " has an unsupported value." }
        integer(value.asJsonObject.get("localStateSchema"), path + ".localStateSchema", "1", "1000")
        text(value.asJsonObject.get("exporterVersion"), path + ".exporterVersion", 1, 128)
    }

    fun validateSourceInventory(value: JsonElement, path: String = "sourceInventory") {
        fields(value, path, setOf("profileCount", "ruleSnapshotCount", "ruleChangeCount", "ruleTimelineCount", "periodCount", "workSnapshotCount", "workEntryCount", "paycheckReceiptCount", "attachmentCount", "unsupportedFinancialRecordKinds", "unsupportedDraftKinds", "omittedFinancialRecordCount", "workBreakCount", "workCorrectionCount", "calculationComponentCount", "auditRevisionCount", "workweekCount", "weeklyAllocationCount", "periodWindowCount", "adoptionCount"))
        integer(value.asJsonObject.get("profileCount"), path + ".profileCount", "0", null)
        integer(value.asJsonObject.get("ruleSnapshotCount"), path + ".ruleSnapshotCount", "0", null)
        integer(value.asJsonObject.get("ruleChangeCount"), path + ".ruleChangeCount", "0", null)
        integer(value.asJsonObject.get("periodCount"), path + ".periodCount", "0", null)
        integer(value.asJsonObject.get("workSnapshotCount"), path + ".workSnapshotCount", "0", null)
        integer(value.asJsonObject.get("workEntryCount"), path + ".workEntryCount", "0", null)
        integer(value.asJsonObject.get("paycheckReceiptCount"), path + ".paycheckReceiptCount", "0", null)
        integer(value.asJsonObject.get("attachmentCount"), path + ".attachmentCount", "0", null)
        array(value.asJsonObject.get("unsupportedFinancialRecordKinds"), path + ".unsupportedFinancialRecordKinds", 0, 100000, true)
        value.asJsonObject.get("unsupportedFinancialRecordKinds").asJsonArray.forEach { item ->
            text(item, path + ".unsupportedFinancialRecordKinds" + "[]", 1, 100)
        }
        array(value.asJsonObject.get("unsupportedDraftKinds"), path + ".unsupportedDraftKinds", 0, 100000, true)
        value.asJsonObject.get("unsupportedDraftKinds").asJsonArray.forEach { item ->
            text(item, path + ".unsupportedDraftKinds" + "[]", 1, 100)
        }
        require(value.asJsonObject.get("omittedFinancialRecordCount") == com.google.gson.JsonParser.parseString("0")) { path + ".omittedFinancialRecordCount" + " has an unsupported value." }
        integer(value.asJsonObject.get("ruleTimelineCount"), path + ".ruleTimelineCount", "0", null)
        integer(value.asJsonObject.get("workBreakCount"), path + ".workBreakCount", "0", null)
        integer(value.asJsonObject.get("workCorrectionCount"), path + ".workCorrectionCount", "0", null)
        integer(value.asJsonObject.get("calculationComponentCount"), path + ".calculationComponentCount", "0", null)
        integer(value.asJsonObject.get("auditRevisionCount"), path + ".auditRevisionCount", "0", null)
        integer(value.asJsonObject.get("workweekCount"), path + ".workweekCount", "0", null)
        integer(value.asJsonObject.get("weeklyAllocationCount"), path + ".weeklyAllocationCount", "0", null)
        integer(value.asJsonObject.get("periodWindowCount"), path + ".periodWindowCount", "0", null)
        integer(value.asJsonObject.get("adoptionCount"), path + ".adoptionCount", "0", null)
    }

    fun validateIdentity(value: JsonElement, path: String = "identity") {
        fields(value, path, setOf("entityType", "portableID", "originClient", "originKind", "originLocalID"))
        require(value.asJsonObject.get("entityType").isJsonPrimitive && value.asJsonObject.get("entityType").asJsonPrimitive.isString && value.asJsonObject.get("entityType").asString in setOf("profile", "ruleSnapshot", "ruleChange", "period", "workSnapshot", "workEntry", "workBreak", "workCorrection", "paycheckReceipt", "calculationComponent", "attachment", "paystub", "periodWindow", "calloutEvent", "ruleTimeline", "auditRevision", "workweek", "weeklyAllocation", "profileAdoption")) { path + ".entityType" + " has an unsupported value." }
        validatePortableID(value.asJsonObject.get("portableID"), path + ".portableID")
        require(value.asJsonObject.get("originClient").isJsonPrimitive && value.asJsonObject.get("originClient").asJsonPrimitive.isString && value.asJsonObject.get("originClient").asString in setOf("ios", "android", "web")) { path + ".originClient" + " has an unsupported value." }
        require(value.asJsonObject.get("originKind").isJsonPrimitive && value.asJsonObject.get("originKind").asJsonPrimitive.isString && value.asJsonObject.get("originKind").asString in setOf("native", "derived")) { path + ".originKind" + " has an unsupported value." }
        if (!value.asJsonObject.get("originLocalID").isJsonNull) {
            validateLocalID(value.asJsonObject.get("originLocalID"), path + ".originLocalID")
        }
    }

    fun validateProfile(value: JsonElement, path: String = "profile") {
        fields(value, path, setOf("id", "name", "timeZone", "cadence", "cycleStartDate", "customEndDate", "ruleRef", "baselineRuleRef", "ruleChangeRefs", "currentPeriodRef", "currentWorkSnapshotRef", "fieldsNotRecorded", "adoptedFromProfileRef"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("name").isJsonNull) {
            text(value.asJsonObject.get("name"), path + ".name", 0, 200)
        }
        if (!value.asJsonObject.get("timeZone").isJsonNull) {
            validateTimeZone(value.asJsonObject.get("timeZone"), path + ".timeZone")
        }
        if (!value.asJsonObject.get("cadence").isJsonNull) {
            require(value.asJsonObject.get("cadence").isJsonPrimitive && value.asJsonObject.get("cadence").asJsonPrimitive.isString && value.asJsonObject.get("cadence").asString in setOf("weekly", "biweekly", "semimonthly", "custom", "manual")) { path + ".cadence" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("cycleStartDate").isJsonNull) {
            validateDate(value.asJsonObject.get("cycleStartDate"), path + ".cycleStartDate")
        }
        if (!value.asJsonObject.get("customEndDate").isJsonNull) {
            validateDate(value.asJsonObject.get("customEndDate"), path + ".customEndDate")
        }
        validatePortableID(value.asJsonObject.get("ruleRef"), path + ".ruleRef")
        if (!value.asJsonObject.get("baselineRuleRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("baselineRuleRef"), path + ".baselineRuleRef")
        }
        array(value.asJsonObject.get("ruleChangeRefs"), path + ".ruleChangeRefs", 0, 100000, true)
        value.asJsonObject.get("ruleChangeRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleChangeRefs" + "[]")
        }
        if (!value.asJsonObject.get("currentPeriodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("currentPeriodRef"), path + ".currentPeriodRef")
        }
        if (!value.asJsonObject.get("currentWorkSnapshotRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("currentWorkSnapshotRef"), path + ".currentWorkSnapshotRef")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("adoptedFromProfileRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("adoptedFromProfileRef"), path + ".adoptedFromProfileRef")
        }
    }

    fun validateRounding(value: JsonElement, path: String = "rounding") {
        fields(value, path, setOf("scope", "scale", "mode"))
        require(value.asJsonObject.get("scope").isJsonPrimitive && value.asJsonObject.get("scope").asJsonPrimitive.isString && value.asJsonObject.get("scope").asString in setOf("payCategory", "legacySegments")) { path + ".scope" + " has an unsupported value." }
        integer(value.asJsonObject.get("scale"), path + ".scale", "0", "8")
        require(value.asJsonObject.get("mode").isJsonPrimitive && value.asJsonObject.get("mode").asJsonPrimitive.isString && value.asJsonObject.get("mode").asString in setOf("halfUp", "halfEven", "down", "up", "towardZero", "awayFromZero", "bankers")) { path + ".mode" + " has an unsupported value." }
    }

    fun validateSourceLocator(value: JsonElement, path: String = "sourceLocator") {
        fields(value, path, setOf("title", "url", "section", "verifiedEpochSeconds", "ruleKey", "documentRef", "documentSHA256", "documentPage", "quotedText"))
        text(value.asJsonObject.get("title"), path + ".title", 1, 300)
        text(value.asJsonObject.get("url"), path + ".url", 0, 2048)
        if (!value.asJsonObject.get("section").isJsonNull) {
            text(value.asJsonObject.get("section"), path + ".section", 0, 300)
        }
        if (!value.asJsonObject.get("verifiedEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("verifiedEpochSeconds"), path + ".verifiedEpochSeconds")
        }
        if (!value.asJsonObject.get("ruleKey").isJsonNull) {
            text(value.asJsonObject.get("ruleKey"), path + ".ruleKey", 0, 100)
        }
        if (!value.asJsonObject.get("documentRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("documentRef"), path + ".documentRef")
        }
        if (!value.asJsonObject.get("documentSHA256").isJsonNull) {
            validateSha256(value.asJsonObject.get("documentSHA256"), path + ".documentSHA256")
        }
        if (!value.asJsonObject.get("documentPage").isJsonNull) {
            integer(value.asJsonObject.get("documentPage"), path + ".documentPage", "0", null)
        }
        if (!value.asJsonObject.get("quotedText").isJsonNull) {
            text(value.asJsonObject.get("quotedText"), path + ".quotedText", 0, 10000)
        }
    }

    fun validateSha256(value: JsonElement, path: String = "sha256") {
        text(value, path, 0, 100000000)
        require(Regex("^[0-9a-f]{64}\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateScheduleWindow(value: JsonElement, path: String = "scheduleWindow") {
        fields(value, path, setOf("weekday", "start", "end"))
        require(value.asJsonObject.get("weekday").isJsonPrimitive && value.asJsonObject.get("weekday").asJsonPrimitive.isString && value.asJsonObject.get("weekday").asString in setOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")) { path + ".weekday" + " has an unsupported value." }
        text(value.asJsonObject.get("start"), path + ".start", 0, 100000000)
        require(Regex("^(?:[01][0-9]|2[0-3]):[0-5][0-9]\$").matches(value.asJsonObject.get("start").asString)) { path + ".start" + " has invalid text." }
        text(value.asJsonObject.get("end"), path + ".end", 0, 100000000)
        require(Regex("^(?:[01][0-9]|2[0-3]):[0-5][0-9]\$").matches(value.asJsonObject.get("end").asString)) { path + ".end" + " has invalid text." }
    }

    fun validateDatePremium(value: JsonElement, path: String = "datePremium") {
        fields(value, path, setOf("date", "multiplier"))
        validateDate(value.asJsonObject.get("date"), path + ".date")
        validateNonnegativeDecimal(value.asJsonObject.get("multiplier"), path + ".multiplier")
    }

    fun validateWeekdayPremium(value: JsonElement, path: String = "weekdayPremium") {
        fields(value, path, setOf("weekday", "multiplier"))
        require(value.asJsonObject.get("weekday").isJsonPrimitive && value.asJsonObject.get("weekday").asJsonPrimitive.isString && value.asJsonObject.get("weekday").asString in setOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")) { path + ".weekday" + " has an unsupported value." }
        validateNonnegativeDecimal(value.asJsonObject.get("multiplier"), path + ".multiplier")
    }

    fun validateDailyTier(value: JsonElement, path: String = "dailyTier") {
        fields(value, path, setOf("afterHours", "multiplier"))
        validateNonnegativeDecimal(value.asJsonObject.get("afterHours"), path + ".afterHours")
        validateNonnegativeDecimal(value.asJsonObject.get("multiplier"), path + ".multiplier")
    }

    fun validateWeeklyRule(value: JsonElement, path: String = "weeklyRule") {
        fields(value, path, setOf("workweekStart", "thresholdHours", "applicability"))
        require(value.asJsonObject.get("workweekStart").isJsonPrimitive && value.asJsonObject.get("workweekStart").asJsonPrimitive.isString && value.asJsonObject.get("workweekStart").asString in setOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")) { path + ".workweekStart" + " has an unsupported value." }
        validateNonnegativeDecimal(value.asJsonObject.get("thresholdHours"), path + ".thresholdHours")
        require(value.asJsonObject.get("applicability").isJsonPrimitive && value.asJsonObject.get("applicability").asJsonPrimitive.isString && value.asJsonObject.get("applicability").asString in setOf("unknown", "coveredNonexemptHourly", "unsupported")) { path + ".applicability" + " has an unsupported value." }
    }

    fun validateRuleSnapshot(value: JsonElement, path: String = "ruleSnapshot") {
        fields(value, path, setOf("id", "ruleID", "version", "displayName", "effectiveStartDate", "effectiveEndDateInclusive", "currency", "hourlyRate", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "weeklyOvertime", "rounding", "sources", "unsupportedRuleNotes", "confirmedAtEpochSeconds", "fieldsNotRecorded", "confirmedByWorker"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        text(value.asJsonObject.get("ruleID"), path + ".ruleID", 1, 128)
        text(value.asJsonObject.get("version"), path + ".version", 1, 128)
        if (!value.asJsonObject.get("displayName").isJsonNull) {
            text(value.asJsonObject.get("displayName"), path + ".displayName", 0, 300)
        }
        if (!value.asJsonObject.get("effectiveStartDate").isJsonNull) {
            validateDate(value.asJsonObject.get("effectiveStartDate"), path + ".effectiveStartDate")
        }
        if (!value.asJsonObject.get("effectiveEndDateInclusive").isJsonNull) {
            validateDate(value.asJsonObject.get("effectiveEndDateInclusive"), path + ".effectiveEndDateInclusive")
        }
        validateCurrency(value.asJsonObject.get("currency"), path + ".currency")
        validateNonnegativeDecimal(value.asJsonObject.get("hourlyRate"), path + ".hourlyRate")
        if (!value.asJsonObject.get("regularSchedule").isJsonNull) {
            array(value.asJsonObject.get("regularSchedule"), path + ".regularSchedule", 0, 64, false)
            value.asJsonObject.get("regularSchedule").asJsonArray.forEach { item ->
                validateScheduleWindow(item, path + ".regularSchedule" + "[]")
            }
        }
        if (!value.asJsonObject.get("dailyOvertimeTiers").isJsonNull) {
            array(value.asJsonObject.get("dailyOvertimeTiers"), path + ".dailyOvertimeTiers", 0, 32, false)
            value.asJsonObject.get("dailyOvertimeTiers").asJsonArray.forEach { item ->
                validateDailyTier(item, path + ".dailyOvertimeTiers" + "[]")
            }
        }
        if (!value.asJsonObject.get("outsideScheduleMultiplier").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("outsideScheduleMultiplier"), path + ".outsideScheduleMultiplier")
        }
        if (!value.asJsonObject.get("weekdayPremiums").isJsonNull) {
            array(value.asJsonObject.get("weekdayPremiums"), path + ".weekdayPremiums", 0, 7, false)
            value.asJsonObject.get("weekdayPremiums").asJsonArray.forEach { item ->
                validateWeekdayPremium(item, path + ".weekdayPremiums" + "[]")
            }
        }
        if (!value.asJsonObject.get("datePremiums").isJsonNull) {
            array(value.asJsonObject.get("datePremiums"), path + ".datePremiums", 0, 10000, false)
            value.asJsonObject.get("datePremiums").asJsonArray.forEach { item ->
                validateDatePremium(item, path + ".datePremiums" + "[]")
            }
        }
        if (!value.asJsonObject.get("calloutMinimumHours").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("calloutMinimumHours"), path + ".calloutMinimumHours")
        }
        if (!value.asJsonObject.get("perDiemPerWorkDate").isJsonNull) {
            validateMoney(value.asJsonObject.get("perDiemPerWorkDate"), path + ".perDiemPerWorkDate")
        }
        if (!value.asJsonObject.get("weeklyOvertime").isJsonNull) {
            validateWeeklyRule(value.asJsonObject.get("weeklyOvertime"), path + ".weeklyOvertime")
        }
        if (!value.asJsonObject.get("rounding").isJsonNull) {
            validateRounding(value.asJsonObject.get("rounding"), path + ".rounding")
        }
        if (!value.asJsonObject.get("sources").isJsonNull) {
            array(value.asJsonObject.get("sources"), path + ".sources", 0, 256, false)
            value.asJsonObject.get("sources").asJsonArray.forEach { item ->
                validateSourceLocator(item, path + ".sources" + "[]")
            }
        }
        if (!value.asJsonObject.get("unsupportedRuleNotes").isJsonNull) {
            text(value.asJsonObject.get("unsupportedRuleNotes"), path + ".unsupportedRuleNotes", 0, 4000)
        }
        if (!value.asJsonObject.get("confirmedAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("confirmedAtEpochSeconds"), path + ".confirmedAtEpochSeconds")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("confirmedByWorker").isJsonNull) {
            require(value.asJsonObject.get("confirmedByWorker").isJsonPrimitive && value.asJsonObject.get("confirmedByWorker").asJsonPrimitive.isBoolean) { path + ".confirmedByWorker" + " must be boolean." }
        }
    }

    fun validateRuleChange(value: JsonElement, path: String = "ruleChange") {
        fields(value, path, setOf("id", "profileRef", "periodRef", "effectiveDate", "sourceProfileRef", "ruleRef", "confirmed", "createdAtEpochSeconds", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("profileRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("profileRef"), path + ".profileRef")
        }
        if (!value.asJsonObject.get("periodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("periodRef"), path + ".periodRef")
        }
        validateDate(value.asJsonObject.get("effectiveDate"), path + ".effectiveDate")
        if (!value.asJsonObject.get("sourceProfileRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("sourceProfileRef"), path + ".sourceProfileRef")
        }
        validatePortableID(value.asJsonObject.get("ruleRef"), path + ".ruleRef")
        if (!value.asJsonObject.get("confirmed").isJsonNull) {
            require(value.asJsonObject.get("confirmed").isJsonPrimitive && value.asJsonObject.get("confirmed").asJsonPrimitive.isBoolean) { path + ".confirmed" + " must be boolean." }
        }
        if (!value.asJsonObject.get("createdAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("createdAtEpochSeconds"), path + ".createdAtEpochSeconds")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateCalendarWindow(value: JsonElement, path: String = "calendarWindow") {
        fields(value, path, setOf("startDate", "endDateInclusive", "endExclusiveDate", "timeZone", "boundaryModel", "startEpochSeconds", "endExclusiveEpochSeconds", "fieldsNotRecorded"))
        if (!value.asJsonObject.get("startDate").isJsonNull) {
            validateDate(value.asJsonObject.get("startDate"), path + ".startDate")
        }
        if (!value.asJsonObject.get("endDateInclusive").isJsonNull) {
            validateDate(value.asJsonObject.get("endDateInclusive"), path + ".endDateInclusive")
        }
        if (!value.asJsonObject.get("endExclusiveDate").isJsonNull) {
            validateDate(value.asJsonObject.get("endExclusiveDate"), path + ".endExclusiveDate")
        }
        if (!value.asJsonObject.get("timeZone").isJsonNull) {
            validateTimeZone(value.asJsonObject.get("timeZone"), path + ".timeZone")
        }
        require(value.asJsonObject.get("boundaryModel").isJsonPrimitive && value.asJsonObject.get("boundaryModel").asJsonPrimitive.isString && value.asJsonObject.get("boundaryModel").asString in setOf("exactInstants", "localDatesOnly", "sourcePeriodUnknown")) { path + ".boundaryModel" + " has an unsupported value." }
        if (!value.asJsonObject.get("startEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("startEpochSeconds"), path + ".startEpochSeconds")
        }
        if (!value.asJsonObject.get("endExclusiveEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("endExclusiveEpochSeconds"), path + ".endExclusiveEpochSeconds")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validatePeriod(value: JsonElement, path: String = "period") {
        fields(value, path, setOf("id", "profileRef", "calendarWindow", "cadence", "isCurrent", "closed", "archivedAtEpochSeconds", "calculationIssue", "ruleRef", "ruleChangeRefs", "currentWorkSnapshotRef", "workSnapshotRefs", "workCorrections", "fieldsNotRecorded", "windowRef", "ruleTimelineRefs", "calculation", "auditCompletedAtEpochSeconds", "workRevision"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("profileRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("profileRef"), path + ".profileRef")
        }
        validateCalendarWindow(value.asJsonObject.get("calendarWindow"), path + ".calendarWindow")
        if (!value.asJsonObject.get("cadence").isJsonNull) {
            require(value.asJsonObject.get("cadence").isJsonPrimitive && value.asJsonObject.get("cadence").asJsonPrimitive.isString && value.asJsonObject.get("cadence").asString in setOf("weekly", "biweekly", "semimonthly", "custom", "manual")) { path + ".cadence" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("isCurrent").isJsonNull) {
            require(value.asJsonObject.get("isCurrent").isJsonPrimitive && value.asJsonObject.get("isCurrent").asJsonPrimitive.isBoolean) { path + ".isCurrent" + " must be boolean." }
        }
        if (!value.asJsonObject.get("closed").isJsonNull) {
            require(value.asJsonObject.get("closed").isJsonPrimitive && value.asJsonObject.get("closed").asJsonPrimitive.isBoolean) { path + ".closed" + " must be boolean." }
        }
        if (!value.asJsonObject.get("archivedAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("archivedAtEpochSeconds"), path + ".archivedAtEpochSeconds")
        }
        if (!value.asJsonObject.get("calculationIssue").isJsonNull) {
            text(value.asJsonObject.get("calculationIssue"), path + ".calculationIssue", 0, 4000)
        }
        if (!value.asJsonObject.get("ruleRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("ruleRef"), path + ".ruleRef")
        }
        array(value.asJsonObject.get("ruleChangeRefs"), path + ".ruleChangeRefs", 0, 100000, true)
        value.asJsonObject.get("ruleChangeRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleChangeRefs" + "[]")
        }
        if (!value.asJsonObject.get("currentWorkSnapshotRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("currentWorkSnapshotRef"), path + ".currentWorkSnapshotRef")
        }
        array(value.asJsonObject.get("workSnapshotRefs"), path + ".workSnapshotRefs", 0, 100000, true)
        value.asJsonObject.get("workSnapshotRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".workSnapshotRefs" + "[]")
        }
        array(value.asJsonObject.get("workCorrections"), path + ".workCorrections", 0, 100000, false)
        value.asJsonObject.get("workCorrections").asJsonArray.forEach { item ->
            validateWorkCorrection(item, path + ".workCorrections" + "[]")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        validatePortableID(value.asJsonObject.get("windowRef"), path + ".windowRef")
        array(value.asJsonObject.get("ruleTimelineRefs"), path + ".ruleTimelineRefs", 0, 100000, true)
        value.asJsonObject.get("ruleTimelineRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleTimelineRefs" + "[]")
        }
        if (!value.asJsonObject.get("calculation").isJsonNull) {
            validateCalculation(value.asJsonObject.get("calculation"), path + ".calculation")
        }
        if (!value.asJsonObject.get("auditCompletedAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("auditCompletedAtEpochSeconds"), path + ".auditCompletedAtEpochSeconds")
        }
        if (!value.asJsonObject.get("workRevision").isJsonNull) {
            integer(value.asJsonObject.get("workRevision"), path + ".workRevision", "0", "1000000")
        }
    }

    fun validateWorkCorrection(value: JsonElement, path: String = "workCorrection") {
        fields(value, path, setOf("id", "workSnapshotRef", "reason", "correctedAtEpochSeconds"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validatePortableID(value.asJsonObject.get("workSnapshotRef"), path + ".workSnapshotRef")
        text(value.asJsonObject.get("reason"), path + ".reason", 0, 2000)
        validateEpochSeconds(value.asJsonObject.get("correctedAtEpochSeconds"), path + ".correctedAtEpochSeconds")
    }

    fun validateWorkSnapshot(value: JsonElement, path: String = "workSnapshot") {
        fields(value, path, setOf("id", "profileRef", "periodRef", "role", "revision", "sourceRef", "work", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validatePortableID(value.asJsonObject.get("profileRef"), path + ".profileRef")
        if (!value.asJsonObject.get("periodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("periodRef"), path + ".periodRef")
        }
        require(value.asJsonObject.get("role").isJsonPrimitive && value.asJsonObject.get("role").asJsonPrimitive.isString && value.asJsonObject.get("role").asString in setOf("currentLedger", "periodRevision", "paycheckInput", "auditRevision", "workCorrection")) { path + ".role" + " has an unsupported value." }
        if (!value.asJsonObject.get("revision").isJsonNull) {
            integer(value.asJsonObject.get("revision"), path + ".revision", "0", "1000000")
        }
        if (!value.asJsonObject.get("sourceRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("sourceRef"), path + ".sourceRef")
        }
        array(value.asJsonObject.get("work"), path + ".work", 0, 50000, false)
        value.asJsonObject.get("work").asJsonArray.forEach { item ->
            validateWorkEntry(item, path + ".work" + "[]")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateWorkEntry(value: JsonElement, path: String = "workEntry") {
        fields(value, path, setOf("id", "startEpochSeconds", "endEpochSeconds", "timeZone", "kind", "calloutEventRef", "unpaidBreaks", "note", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validateEpochSeconds(value.asJsonObject.get("startEpochSeconds"), path + ".startEpochSeconds")
        validateEpochSeconds(value.asJsonObject.get("endEpochSeconds"), path + ".endEpochSeconds")
        validateTimeZone(value.asJsonObject.get("timeZone"), path + ".timeZone")
        require(value.asJsonObject.get("kind").isJsonPrimitive && value.asJsonObject.get("kind").asJsonPrimitive.isString && value.asJsonObject.get("kind").asString in setOf("regular", "callout", "other")) { path + ".kind" + " has an unsupported value." }
        if (!value.asJsonObject.get("calloutEventRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("calloutEventRef"), path + ".calloutEventRef")
        }
        array(value.asJsonObject.get("unpaidBreaks"), path + ".unpaidBreaks", 0, 100, false)
        value.asJsonObject.get("unpaidBreaks").asJsonArray.forEach { item ->
            validateWorkBreak(item, path + ".unpaidBreaks" + "[]")
        }
        if (!value.asJsonObject.get("note").isJsonNull) {
            text(value.asJsonObject.get("note"), path + ".note", 0, 4000)
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateWorkBreak(value: JsonElement, path: String = "workBreak") {
        fields(value, path, setOf("id", "startEpochSeconds", "endEpochSeconds"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validateEpochSeconds(value.asJsonObject.get("startEpochSeconds"), path + ".startEpochSeconds")
        validateEpochSeconds(value.asJsonObject.get("endEpochSeconds"), path + ".endEpochSeconds")
    }

    fun validateMoney(value: JsonElement, path: String = "money") {
        fields(value, path, setOf("amount", "currency"))
        validateDecimal(value.asJsonObject.get("amount"), path + ".amount")
        validateCurrency(value.asJsonObject.get("currency"), path + ".currency")
    }

    fun validatePaycheckReceipt(value: JsonElement, path: String = "paycheckReceipt") {
        fields(value, path, setOf("receiptKind", "id", "periodRef", "workSnapshotRef", "createdAtEpochSeconds", "supersedesReceiptRef", "producer", "ruleRefs", "sourcePeriod", "paystubFacts", "lineFacts", "reviewFacts", "calculation", "assessment", "reconciliation", "attachmentRefs", "fieldsNotRecorded", "auditRevisionRef", "targetWindowRef", "targetWindow", "targetCadence", "targetRuleChangeRefs"))
        require(value.asJsonObject.get("receiptKind") == com.google.gson.JsonParser.parseString("\"paycheck-v1\"")) { path + ".receiptKind" + " has an unsupported value." }
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("periodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("periodRef"), path + ".periodRef")
        }
        validatePortableID(value.asJsonObject.get("workSnapshotRef"), path + ".workSnapshotRef")
        validateEpochSeconds(value.asJsonObject.get("createdAtEpochSeconds"), path + ".createdAtEpochSeconds")
        if (!value.asJsonObject.get("supersedesReceiptRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("supersedesReceiptRef"), path + ".supersedesReceiptRef")
        }
        validateProducer(value.asJsonObject.get("producer"), path + ".producer")
        array(value.asJsonObject.get("ruleRefs"), path + ".ruleRefs", 0, 100000, true)
        value.asJsonObject.get("ruleRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleRefs" + "[]")
        }
        if (!value.asJsonObject.get("sourcePeriod").isJsonNull) {
            validateSourcePeriod(value.asJsonObject.get("sourcePeriod"), path + ".sourcePeriod")
        }
        validatePaystubFacts(value.asJsonObject.get("paystubFacts"), path + ".paystubFacts")
        validateLineFacts(value.asJsonObject.get("lineFacts"), path + ".lineFacts")
        validateReviewFacts(value.asJsonObject.get("reviewFacts"), path + ".reviewFacts")
        if (!value.asJsonObject.get("calculation").isJsonNull) {
            validateCalculation(value.asJsonObject.get("calculation"), path + ".calculation")
        }
        validateAssessment(value.asJsonObject.get("assessment"), path + ".assessment")
        if (!value.asJsonObject.get("reconciliation").isJsonNull) {
            validateReconciliation(value.asJsonObject.get("reconciliation"), path + ".reconciliation")
        }
        array(value.asJsonObject.get("attachmentRefs"), path + ".attachmentRefs", 0, 100000, true)
        value.asJsonObject.get("attachmentRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".attachmentRefs" + "[]")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("auditRevisionRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("auditRevisionRef"), path + ".auditRevisionRef")
        }
        validatePortableID(value.asJsonObject.get("targetWindowRef"), path + ".targetWindowRef")
        validateCalendarWindow(value.asJsonObject.get("targetWindow"), path + ".targetWindow")
        if (!value.asJsonObject.get("targetCadence").isJsonNull) {
            require(value.asJsonObject.get("targetCadence").isJsonPrimitive && value.asJsonObject.get("targetCadence").asJsonPrimitive.isString && value.asJsonObject.get("targetCadence").asString in setOf("weekly", "biweekly", "semimonthly", "custom", "manual")) { path + ".targetCadence" + " has an unsupported value." }
        }
        array(value.asJsonObject.get("targetRuleChangeRefs"), path + ".targetRuleChangeRefs", 0, 100000, true)
        value.asJsonObject.get("targetRuleChangeRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".targetRuleChangeRefs" + "[]")
        }
    }

    fun validateProducer(value: JsonElement, path: String = "producer") {
        fields(value, path, setOf("client", "localStateSchema", "calculationEngineID", "calculationEngineVersion", "assessmentEngineID", "assessmentEngineVersion", "fieldsNotRecorded"))
        require(value.asJsonObject.get("client").isJsonPrimitive && value.asJsonObject.get("client").asJsonPrimitive.isString && value.asJsonObject.get("client").asString in setOf("ios", "android", "web")) { path + ".client" + " has an unsupported value." }
        if (!value.asJsonObject.get("localStateSchema").isJsonNull) {
            integer(value.asJsonObject.get("localStateSchema"), path + ".localStateSchema", "1", "1000")
        }
        if (!value.asJsonObject.get("calculationEngineID").isJsonNull) {
            text(value.asJsonObject.get("calculationEngineID"), path + ".calculationEngineID", 0, 160)
        }
        if (!value.asJsonObject.get("calculationEngineVersion").isJsonNull) {
            if (value.asJsonObject.get("calculationEngineVersion").isJsonPrimitive && value.asJsonObject.get("calculationEngineVersion").asJsonPrimitive.isString) text(value.asJsonObject.get("calculationEngineVersion"), path + ".calculationEngineVersion", 0, 64) else integer(value.asJsonObject.get("calculationEngineVersion"), path + ".calculationEngineVersion", null, null)
        }
        if (!value.asJsonObject.get("assessmentEngineID").isJsonNull) {
            text(value.asJsonObject.get("assessmentEngineID"), path + ".assessmentEngineID", 0, 160)
        }
        if (!value.asJsonObject.get("assessmentEngineVersion").isJsonNull) {
            if (value.asJsonObject.get("assessmentEngineVersion").isJsonPrimitive && value.asJsonObject.get("assessmentEngineVersion").asJsonPrimitive.isString) text(value.asJsonObject.get("assessmentEngineVersion"), path + ".assessmentEngineVersion", 0, 64) else integer(value.asJsonObject.get("assessmentEngineVersion"), path + ".assessmentEngineVersion", null, null)
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validatePaystubFacts(value: JsonElement, path: String = "paystubFacts") {
        fields(value, path, setOf("id", "periodStartDate", "periodEndDateInclusive", "currency", "grossPay", "regularHours", "regularPay", "overtimeHours", "overtimePay", "doubleTimeHours", "doubleTimePay", "calloutPay", "perDiemPay", "notes", "confirmedAtEpochSeconds", "evidenceRef", "fieldsNotRecorded", "confirmed"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("periodStartDate").isJsonNull) {
            validateDate(value.asJsonObject.get("periodStartDate"), path + ".periodStartDate")
        }
        if (!value.asJsonObject.get("periodEndDateInclusive").isJsonNull) {
            validateDate(value.asJsonObject.get("periodEndDateInclusive"), path + ".periodEndDateInclusive")
        }
        validateCurrency(value.asJsonObject.get("currency"), path + ".currency")
        validateNonnegativeDecimal(value.asJsonObject.get("grossPay"), path + ".grossPay")
        if (!value.asJsonObject.get("regularHours").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("regularHours"), path + ".regularHours")
        }
        if (!value.asJsonObject.get("regularPay").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("regularPay"), path + ".regularPay")
        }
        if (!value.asJsonObject.get("overtimeHours").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("overtimeHours"), path + ".overtimeHours")
        }
        if (!value.asJsonObject.get("overtimePay").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("overtimePay"), path + ".overtimePay")
        }
        if (!value.asJsonObject.get("doubleTimeHours").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("doubleTimeHours"), path + ".doubleTimeHours")
        }
        if (!value.asJsonObject.get("doubleTimePay").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("doubleTimePay"), path + ".doubleTimePay")
        }
        if (!value.asJsonObject.get("calloutPay").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("calloutPay"), path + ".calloutPay")
        }
        if (!value.asJsonObject.get("perDiemPay").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("perDiemPay"), path + ".perDiemPay")
        }
        if (!value.asJsonObject.get("notes").isJsonNull) {
            text(value.asJsonObject.get("notes"), path + ".notes", 0, 4000)
        }
        if (!value.asJsonObject.get("confirmedAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("confirmedAtEpochSeconds"), path + ".confirmedAtEpochSeconds")
        }
        if (!value.asJsonObject.get("evidenceRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("evidenceRef"), path + ".evidenceRef")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("confirmed").isJsonNull) {
            require(value.asJsonObject.get("confirmed").isJsonPrimitive && value.asJsonObject.get("confirmed").asJsonPrimitive.isBoolean) { path + ".confirmed" + " must be boolean." }
        }
    }

    fun validateLineFacts(value: JsonElement, path: String = "lineFacts") {
        fields(value, path, setOf("grossBasis", "lineLayout", "hoursBasis", "guaranteeLayout", "amounts", "hours", "reviewedFields", "suggestions", "hasAdditionalUnmappedPay", "workComplete", "earningsLinesComplete", "fieldsNotRecorded"))
        if (!value.asJsonObject.get("grossBasis").isJsonNull) {
            require(value.asJsonObject.get("grossBasis").isJsonPrimitive && value.asJsonObject.get("grossBasis").asJsonPrimitive.isString && value.asJsonObject.get("grossBasis").asString in setOf("unconfirmed", "wagesOnly", "wagesAndPerDiem")) { path + ".grossBasis" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("lineLayout").isJsonNull) {
            require(value.asJsonObject.get("lineLayout").isJsonPrimitive && value.asJsonObject.get("lineLayout").asJsonPrimitive.isString && value.asJsonObject.get("lineLayout").asString in setOf("unconfirmed", "fullRateBuckets", "basePlusPremium")) { path + ".lineLayout" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("hoursBasis").isJsonNull) {
            require(value.asJsonObject.get("hoursBasis").isJsonPrimitive && value.asJsonObject.get("hoursBasis").asJsonPrimitive.isString && value.asJsonObject.get("hoursBasis").asString in setOf("unconfirmed", "actualWork", "paidEquivalents")) { path + ".hoursBasis" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("guaranteeLayout").isJsonNull) {
            require(value.asJsonObject.get("guaranteeLayout").isJsonPrimitive && value.asJsonObject.get("guaranteeLayout").asJsonPrimitive.isString && value.asJsonObject.get("guaranteeLayout").asString in setOf("unconfirmed", "separateLine", "includedInHourlyLines")) { path + ".guaranteeLayout" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("amounts").isJsonNull) {
            array(value.asJsonObject.get("amounts"), path + ".amounts", 0, 100000, false)
            value.asJsonObject.get("amounts").asJsonArray.forEach { item ->
                validateLineAmount(item, path + ".amounts" + "[]")
            }
        }
        if (!value.asJsonObject.get("hours").isJsonNull) {
            array(value.asJsonObject.get("hours"), path + ".hours", 0, 100000, false)
            value.asJsonObject.get("hours").asJsonArray.forEach { item ->
                validateLineHours(item, path + ".hours" + "[]")
            }
        }
        if (!value.asJsonObject.get("reviewedFields").isJsonNull) {
            array(value.asJsonObject.get("reviewedFields"), path + ".reviewedFields", 0, 100000, true)
            value.asJsonObject.get("reviewedFields").asJsonArray.forEach { item ->
                text(item, path + ".reviewedFields" + "[]", 0, 80)
            }
        }
        if (!value.asJsonObject.get("suggestions").isJsonNull) {
            array(value.asJsonObject.get("suggestions"), path + ".suggestions", 0, 100000, false)
            value.asJsonObject.get("suggestions").asJsonArray.forEach { item ->
                validateOcrSuggestion(item, path + ".suggestions" + "[]")
            }
        }
        if (!value.asJsonObject.get("hasAdditionalUnmappedPay").isJsonNull) {
            require(value.asJsonObject.get("hasAdditionalUnmappedPay").isJsonPrimitive && value.asJsonObject.get("hasAdditionalUnmappedPay").asJsonPrimitive.isBoolean) { path + ".hasAdditionalUnmappedPay" + " must be boolean." }
        }
        if (!value.asJsonObject.get("workComplete").isJsonNull) {
            require(value.asJsonObject.get("workComplete").isJsonPrimitive && value.asJsonObject.get("workComplete").asJsonPrimitive.isBoolean) { path + ".workComplete" + " must be boolean." }
        }
        if (!value.asJsonObject.get("earningsLinesComplete").isJsonNull) {
            require(value.asJsonObject.get("earningsLinesComplete").isJsonPrimitive && value.asJsonObject.get("earningsLinesComplete").asJsonPrimitive.isBoolean) { path + ".earningsLinesComplete" + " must be boolean." }
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateLineAmount(value: JsonElement, path: String = "lineAmount") {
        fields(value, path, setOf("field", "amount"))
        text(value.asJsonObject.get("field"), path + ".field", 0, 80)
        validateMoney(value.asJsonObject.get("amount"), path + ".amount")
    }

    fun validateLineHours(value: JsonElement, path: String = "lineHours") {
        fields(value, path, setOf("field", "hours"))
        text(value.asJsonObject.get("field"), path + ".field", 0, 80)
        validateNonnegativeDecimal(value.asJsonObject.get("hours"), path + ".hours")
    }

    fun validateOcrSuggestion(value: JsonElement, path: String = "ocrSuggestion") {
        fields(value, path, setOf("field", "value", "sourceText", "region", "confidence", "reason"))
        text(value.asJsonObject.get("field"), path + ".field", 0, 80)
        if (!value.asJsonObject.get("value").isJsonNull) {
            text(value.asJsonObject.get("value"), path + ".value", 0, 512)
        }
        text(value.asJsonObject.get("sourceText"), path + ".sourceText", 0, 4000)
        if (!value.asJsonObject.get("region").isJsonNull) {
            validateSourceRegion(value.asJsonObject.get("region"), path + ".region")
        }
        validateSourceScalar(value.asJsonObject.get("confidence"), path + ".confidence")
        if (!value.asJsonObject.get("reason").isJsonNull) {
            text(value.asJsonObject.get("reason"), path + ".reason", 0, 2000)
        }
    }

    fun validateSourceRegion(value: JsonElement, path: String = "sourceRegion") {
        fields(value, path, setOf("x", "y", "width", "height", "page"))
        validateSourceScalar(value.asJsonObject.get("x"), path + ".x")
        validateSourceScalar(value.asJsonObject.get("y"), path + ".y")
        validateSourceScalar(value.asJsonObject.get("width"), path + ".width")
        validateSourceScalar(value.asJsonObject.get("height"), path + ".height")
        if (!value.asJsonObject.get("page").isJsonNull) {
            integer(value.asJsonObject.get("page"), path + ".page", "0", "10000")
        }
    }

    fun validateReviewFacts(value: JsonElement, path: String = "reviewFacts") {
        fields(value, path, setOf("completeWorkConfirmed", "ruleCoverageConfirmed", "unreviewedFields", "weeklyReviewPending", "fieldsNotRecorded"))
        if (!value.asJsonObject.get("completeWorkConfirmed").isJsonNull) {
            require(value.asJsonObject.get("completeWorkConfirmed").isJsonPrimitive && value.asJsonObject.get("completeWorkConfirmed").asJsonPrimitive.isBoolean) { path + ".completeWorkConfirmed" + " must be boolean." }
        }
        if (!value.asJsonObject.get("ruleCoverageConfirmed").isJsonNull) {
            require(value.asJsonObject.get("ruleCoverageConfirmed").isJsonPrimitive && value.asJsonObject.get("ruleCoverageConfirmed").asJsonPrimitive.isBoolean) { path + ".ruleCoverageConfirmed" + " must be boolean." }
        }
        if (!value.asJsonObject.get("unreviewedFields").isJsonNull) {
            require(value.asJsonObject.get("unreviewedFields").isJsonPrimitive && value.asJsonObject.get("unreviewedFields").asJsonPrimitive.isBoolean) { path + ".unreviewedFields" + " must be boolean." }
        }
        if (!value.asJsonObject.get("weeklyReviewPending").isJsonNull) {
            require(value.asJsonObject.get("weeklyReviewPending").isJsonPrimitive && value.asJsonObject.get("weeklyReviewPending").asJsonPrimitive.isBoolean) { path + ".weeklyReviewPending" + " must be boolean." }
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateCalculation(value: JsonElement, path: String = "calculation") {
        fields(value, path, setOf("agreementID", "agreementVersion", "primaryRuleRef", "agreementSnapshotRefs", "currency", "total", "provenance", "weeklyRegularRate", "components", "fieldsNotRecorded", "engine", "coverage", "wages", "allowances", "ruleTimelineRef", "ruleChangeRefs"))
        if (!value.asJsonObject.get("agreementID").isJsonNull) {
            text(value.asJsonObject.get("agreementID"), path + ".agreementID", 0, 128)
        }
        if (!value.asJsonObject.get("agreementVersion").isJsonNull) {
            text(value.asJsonObject.get("agreementVersion"), path + ".agreementVersion", 0, 128)
        }
        if (!value.asJsonObject.get("primaryRuleRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("primaryRuleRef"), path + ".primaryRuleRef")
        }
        array(value.asJsonObject.get("agreementSnapshotRefs"), path + ".agreementSnapshotRefs", 0, 100000, true)
        value.asJsonObject.get("agreementSnapshotRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".agreementSnapshotRefs" + "[]")
        }
        validateCurrency(value.asJsonObject.get("currency"), path + ".currency")
        if (!value.asJsonObject.get("total").isJsonNull) {
            validateMoney(value.asJsonObject.get("total"), path + ".total")
        }
        if (!value.asJsonObject.get("provenance").isJsonNull) {
            validateCalculationProvenance(value.asJsonObject.get("provenance"), path + ".provenance")
        }
        if (!value.asJsonObject.get("weeklyRegularRate").isJsonNull) {
            validateWeeklyResult(value.asJsonObject.get("weeklyRegularRate"), path + ".weeklyRegularRate")
        }
        array(value.asJsonObject.get("components"), path + ".components", 0, 100000, false)
        value.asJsonObject.get("components").asJsonArray.forEach { item ->
            validateComponent(item, path + ".components" + "[]")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("engine").isJsonNull) {
            text(value.asJsonObject.get("engine"), path + ".engine", 0, 160)
        }
        if (!value.asJsonObject.get("coverage").isJsonNull) {
            text(value.asJsonObject.get("coverage"), path + ".coverage", 0, 160)
        }
        if (!value.asJsonObject.get("wages").isJsonNull) {
            validateMoney(value.asJsonObject.get("wages"), path + ".wages")
        }
        if (!value.asJsonObject.get("allowances").isJsonNull) {
            validateMoney(value.asJsonObject.get("allowances"), path + ".allowances")
        }
        if (!value.asJsonObject.get("ruleTimelineRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("ruleTimelineRef"), path + ".ruleTimelineRef")
        }
        array(value.asJsonObject.get("ruleChangeRefs"), path + ".ruleChangeRefs", 0, 100000, true)
        value.asJsonObject.get("ruleChangeRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleChangeRefs" + "[]")
        }
    }

    fun validateCalculationProvenance(value: JsonElement, path: String = "calculationProvenance") {
        fields(value, path, setOf("engine", "rounding", "callout"))
        text(value.asJsonObject.get("engine"), path + ".engine", 0, 160)
        text(value.asJsonObject.get("rounding"), path + ".rounding", 0, 160)
        text(value.asJsonObject.get("callout"), path + ".callout", 0, 160)
    }

    fun validateComponent(value: JsonElement, path: String = "component") {
        fields(value, path, setOf("id", "category", "workRef", "localDate", "hours", "workedSeconds", "multiplier", "amount", "explanation", "ruleKeys", "baseRate", "appliedAgreement", "unroundedAmount", "baseTimeNumerator", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        require(value.asJsonObject.get("category").isJsonPrimitive && value.asJsonObject.get("category").asJsonPrimitive.isString && value.asJsonObject.get("category").asString in setOf("workedHours", "calloutGuarantee", "perDiem")) { path + ".category" + " has an unsupported value." }
        if (!value.asJsonObject.get("workRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("workRef"), path + ".workRef")
        }
        validateDate(value.asJsonObject.get("localDate"), path + ".localDate")
        if (!value.asJsonObject.get("hours").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("hours"), path + ".hours")
        }
        if (!value.asJsonObject.get("workedSeconds").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("workedSeconds"), path + ".workedSeconds")
        }
        if (!value.asJsonObject.get("multiplier").isJsonNull) {
            validateNonnegativeDecimal(value.asJsonObject.get("multiplier"), path + ".multiplier")
        }
        validateMoney(value.asJsonObject.get("amount"), path + ".amount")
        text(value.asJsonObject.get("explanation"), path + ".explanation", 0, 2000)
        if (!value.asJsonObject.get("ruleKeys").isJsonNull) {
            array(value.asJsonObject.get("ruleKeys"), path + ".ruleKeys", 0, 100000, false)
            value.asJsonObject.get("ruleKeys").asJsonArray.forEach { item ->
                text(item, path + ".ruleKeys" + "[]", 0, 100)
            }
        }
        if (!value.asJsonObject.get("baseRate").isJsonNull) {
            validateMoney(value.asJsonObject.get("baseRate"), path + ".baseRate")
        }
        if (!value.asJsonObject.get("appliedAgreement").isJsonNull) {
            validateAgreementReference(value.asJsonObject.get("appliedAgreement"), path + ".appliedAgreement")
        }
        if (!value.asJsonObject.get("unroundedAmount").isJsonNull) {
            validateMoney(value.asJsonObject.get("unroundedAmount"), path + ".unroundedAmount")
        }
        if (!value.asJsonObject.get("baseTimeNumerator").isJsonNull) {
            validateDecimal(value.asJsonObject.get("baseTimeNumerator"), path + ".baseTimeNumerator")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateAgreementReference(value: JsonElement, path: String = "agreementReference") {
        fields(value, path, setOf("ruleRef", "ruleID", "version", "hourlyRate"))
        validatePortableID(value.asJsonObject.get("ruleRef"), path + ".ruleRef")
        text(value.asJsonObject.get("ruleID"), path + ".ruleID", 0, 128)
        text(value.asJsonObject.get("version"), path + ".version", 0, 128)
        if (!value.asJsonObject.get("hourlyRate").isJsonNull) {
            validateMoney(value.asJsonObject.get("hourlyRate"), path + ".hourlyRate")
        }
    }

    fun validateWeeklyResult(value: JsonElement, path: String = "weeklyResult") {
        fields(value, path, setOf("workweekID", "weekStart", "workweekStart", "qualifyingHours", "includableRemuneration", "regularRate", "overtimeHours", "statutoryAdditionalPremium", "eligibleExtraPremiumCredit", "remainingAdditionalPremium", "cashRemuneration", "expectedCash", "allocations", "engineVersion", "startEpochSeconds", "endEpochSeconds", "timeZone", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("workweekID"), path + ".workweekID")
        validateDate(value.asJsonObject.get("weekStart"), path + ".weekStart")
        require(value.asJsonObject.get("workweekStart").isJsonPrimitive && value.asJsonObject.get("workweekStart").asJsonPrimitive.isString && value.asJsonObject.get("workweekStart").asString in setOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")) { path + ".workweekStart" + " has an unsupported value." }
        validateNonnegativeDecimal(value.asJsonObject.get("qualifyingHours"), path + ".qualifyingHours")
        validateMoney(value.asJsonObject.get("includableRemuneration"), path + ".includableRemuneration")
        if (!value.asJsonObject.get("regularRate").isJsonNull) {
            validateMoney(value.asJsonObject.get("regularRate"), path + ".regularRate")
        }
        validateNonnegativeDecimal(value.asJsonObject.get("overtimeHours"), path + ".overtimeHours")
        validateMoney(value.asJsonObject.get("statutoryAdditionalPremium"), path + ".statutoryAdditionalPremium")
        validateMoney(value.asJsonObject.get("eligibleExtraPremiumCredit"), path + ".eligibleExtraPremiumCredit")
        validateMoney(value.asJsonObject.get("remainingAdditionalPremium"), path + ".remainingAdditionalPremium")
        validateMoney(value.asJsonObject.get("cashRemuneration"), path + ".cashRemuneration")
        validateMoney(value.asJsonObject.get("expectedCash"), path + ".expectedCash")
        array(value.asJsonObject.get("allocations"), path + ".allocations", 0, 100000, false)
        value.asJsonObject.get("allocations").asJsonArray.forEach { item ->
            validateWeeklyAllocation(item, path + ".allocations" + "[]")
        }
        text(value.asJsonObject.get("engineVersion"), path + ".engineVersion", 0, 160)
        if (!value.asJsonObject.get("startEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("startEpochSeconds"), path + ".startEpochSeconds")
        }
        if (!value.asJsonObject.get("endEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("endEpochSeconds"), path + ".endEpochSeconds")
        }
        if (!value.asJsonObject.get("timeZone").isJsonNull) {
            validateTimeZone(value.asJsonObject.get("timeZone"), path + ".timeZone")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateWeeklyAllocation(value: JsonElement, path: String = "weeklyAllocation") {
        fields(value, path, setOf("id", "periodRef", "amount", "basis"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        if (!value.asJsonObject.get("periodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("periodRef"), path + ".periodRef")
        }
        validateMoney(value.asJsonObject.get("amount"), path + ".amount")
        validateMoney(value.asJsonObject.get("basis"), path + ".basis")
    }

    fun validateAssessment(value: JsonElement, path: String = "assessment") {
        fields(value, path, setOf("engineID", "engineVersion", "verdict", "scope", "expectedGross", "paidGross", "difference", "comparisons", "reviewReasons", "scopeNotes", "weeklyContextCount", "weeklyReviewRefs", "fieldsNotRecorded", "periodMatch", "reportedPeriod"))
        if (!value.asJsonObject.get("engineID").isJsonNull) {
            text(value.asJsonObject.get("engineID"), path + ".engineID", 0, 160)
        }
        if (!value.asJsonObject.get("engineVersion").isJsonNull) {
            if (value.asJsonObject.get("engineVersion").isJsonPrimitive && value.asJsonObject.get("engineVersion").asJsonPrimitive.isString) text(value.asJsonObject.get("engineVersion"), path + ".engineVersion", 0, 64) else integer(value.asJsonObject.get("engineVersion"), path + ".engineVersion", null, null)
        }
        require(value.asJsonObject.get("verdict").isJsonPrimitive && value.asJsonObject.get("verdict").asJsonPrimitive.isString && value.asJsonObject.get("verdict").asString in setOf("matches", "possibleShortfall", "possibleOverpayment", "needsReview", "notComparable")) { path + ".verdict" + " has an unsupported value." }
        require(value.asJsonObject.get("scope").isJsonPrimitive && value.asJsonObject.get("scope").asJsonPrimitive.isString && value.asJsonObject.get("scope").asString in setOf("grossOnly", "confirmedLines")) { path + ".scope" + " has an unsupported value." }
        if (!value.asJsonObject.get("expectedGross").isJsonNull) {
            validateMoney(value.asJsonObject.get("expectedGross"), path + ".expectedGross")
        }
        validateMoney(value.asJsonObject.get("paidGross"), path + ".paidGross")
        if (!value.asJsonObject.get("difference").isJsonNull) {
            validateMoney(value.asJsonObject.get("difference"), path + ".difference")
        }
        array(value.asJsonObject.get("comparisons"), path + ".comparisons", 0, 100000, false)
        value.asJsonObject.get("comparisons").asJsonArray.forEach { item ->
            validateComparison(item, path + ".comparisons" + "[]")
        }
        array(value.asJsonObject.get("reviewReasons"), path + ".reviewReasons", 0, 100000, false)
        value.asJsonObject.get("reviewReasons").asJsonArray.forEach { item ->
            text(item, path + ".reviewReasons" + "[]", 0, 4000)
        }
        if (!value.asJsonObject.get("scopeNotes").isJsonNull) {
            array(value.asJsonObject.get("scopeNotes"), path + ".scopeNotes", 0, 100000, false)
            value.asJsonObject.get("scopeNotes").asJsonArray.forEach { item ->
                text(item, path + ".scopeNotes" + "[]", 0, 4000)
            }
        }
        if (!value.asJsonObject.get("weeklyContextCount").isJsonNull) {
            integer(value.asJsonObject.get("weeklyContextCount"), path + ".weeklyContextCount", "0", "128")
        }
        if (!value.asJsonObject.get("weeklyReviewRefs").isJsonNull) {
            array(value.asJsonObject.get("weeklyReviewRefs"), path + ".weeklyReviewRefs", 0, 100000, false)
            value.asJsonObject.get("weeklyReviewRefs").asJsonArray.forEach { item ->
                validatePortableID(item, path + ".weeklyReviewRefs" + "[]")
            }
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
        if (!value.asJsonObject.get("periodMatch").isJsonNull) {
            require(value.asJsonObject.get("periodMatch").isJsonPrimitive && value.asJsonObject.get("periodMatch").asJsonPrimitive.isString && value.asJsonObject.get("periodMatch").asString in setOf("confirmedSamePeriod", "differentPeriod", "unconfirmedPeriod")) { path + ".periodMatch" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("reportedPeriod").isJsonNull) {
            validateSourcePeriod(value.asJsonObject.get("reportedPeriod"), path + ".reportedPeriod")
        }
    }

    fun validateComparison(value: JsonElement, path: String = "comparison") {
        fields(value, path, setOf("id", "field", "expected", "paid", "difference", "unit", "currency", "componentRefs"))
        text(value.asJsonObject.get("id"), path + ".id", 0, 100)
        require(value.asJsonObject.get("field").isJsonPrimitive && value.asJsonObject.get("field").asJsonPrimitive.isString && value.asJsonObject.get("field").asString in setOf("grossPay", "regularHours", "regularPay", "overtimeHours", "overtimePay", "doubleTimeHours", "doubleTimePay", "calloutPay", "perDiemPay")) { path + ".field" + " has an unsupported value." }
        validateDecimal(value.asJsonObject.get("expected"), path + ".expected")
        validateDecimal(value.asJsonObject.get("paid"), path + ".paid")
        validateDecimal(value.asJsonObject.get("difference"), path + ".difference")
        require(value.asJsonObject.get("unit").isJsonPrimitive && value.asJsonObject.get("unit").asJsonPrimitive.isString && value.asJsonObject.get("unit").asString in setOf("money", "hours")) { path + ".unit" + " has an unsupported value." }
        validateCurrency(value.asJsonObject.get("currency"), path + ".currency")
        array(value.asJsonObject.get("componentRefs"), path + ".componentRefs", 0, 100000, true)
        value.asJsonObject.get("componentRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".componentRefs" + "[]")
        }
    }

    fun validateReconciliation(value: JsonElement, path: String = "reconciliation") {
        fields(value, path, setOf("expectedGross", "actualGross", "difference", "direction"))
        validateMoney(value.asJsonObject.get("expectedGross"), path + ".expectedGross")
        validateMoney(value.asJsonObject.get("actualGross"), path + ".actualGross")
        validateMoney(value.asJsonObject.get("difference"), path + ".difference")
        require(value.asJsonObject.get("direction").isJsonPrimitive && value.asJsonObject.get("direction").asJsonPrimitive.isString && value.asJsonObject.get("direction").asString in setOf("matches", "possibleUnderpayment", "possibleOverpayment")) { path + ".direction" + " has an unsupported value." }
    }

    fun validateAttachment(value: JsonElement, path: String = "attachment") {
        fields(value, path, setOf("id", "kind", "originalFilename", "mediaType", "sourceKind", "createdAtEpochSeconds", "recognizedText", "sha256", "byteLength", "bytesBase64", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        require(value.asJsonObject.get("kind").isJsonPrimitive && value.asJsonObject.get("kind").asJsonPrimitive.isString && value.asJsonObject.get("kind").asString in setOf("paystubOriginal", "sourceDocumentOriginal")) { path + ".kind" + " has an unsupported value." }
        text(value.asJsonObject.get("originalFilename"), path + ".originalFilename", 1, 255)
        text(value.asJsonObject.get("mediaType"), path + ".mediaType", 0, 100000000)
        require(Regex("^[A-Za-z0-9!#\$&^_.+-]+/[A-Za-z0-9!#\$&^_.+-]+\$").matches(value.asJsonObject.get("mediaType").asString)) { path + ".mediaType" + " has invalid text." }
        if (!value.asJsonObject.get("sourceKind").isJsonNull) {
            require(value.asJsonObject.get("sourceKind").isJsonPrimitive && value.asJsonObject.get("sourceKind").asJsonPrimitive.isString && value.asJsonObject.get("sourceKind").asString in setOf("scan", "photo", "file", "manual")) { path + ".sourceKind" + " has an unsupported value." }
        }
        if (!value.asJsonObject.get("createdAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("createdAtEpochSeconds"), path + ".createdAtEpochSeconds")
        }
        if (!value.asJsonObject.get("recognizedText").isJsonNull) {
            text(value.asJsonObject.get("recognizedText"), path + ".recognizedText", 0, 200000)
        }
        validateSha256(value.asJsonObject.get("sha256"), path + ".sha256")
        integer(value.asJsonObject.get("byteLength"), path + ".byteLength", "1", "26214400")
        text(value.asJsonObject.get("bytesBase64"), path + ".bytesBase64", 4, 100000000)
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateRuleTimeline(value: JsonElement, path: String = "ruleTimeline") {
        fields(value, path, setOf("id", "periodRef", "baselineRuleRef", "ruleChangeRefs", "createdAtEpochSeconds", "confirmed", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validatePortableID(value.asJsonObject.get("periodRef"), path + ".periodRef")
        if (!value.asJsonObject.get("baselineRuleRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("baselineRuleRef"), path + ".baselineRuleRef")
        }
        array(value.asJsonObject.get("ruleChangeRefs"), path + ".ruleChangeRefs", 0, 100000, true)
        value.asJsonObject.get("ruleChangeRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".ruleChangeRefs" + "[]")
        }
        if (!value.asJsonObject.get("createdAtEpochSeconds").isJsonNull) {
            validateEpochSeconds(value.asJsonObject.get("createdAtEpochSeconds"), path + ".createdAtEpochSeconds")
        }
        if (!value.asJsonObject.get("confirmed").isJsonNull) {
            require(value.asJsonObject.get("confirmed").isJsonPrimitive && value.asJsonObject.get("confirmed").asJsonPrimitive.isBoolean) { path + ".confirmed" + " must be boolean." }
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateSourcePeriod(value: JsonElement, path: String = "sourcePeriod") {
        fields(value, path, setOf("startDate", "endDateInclusive", "timeZone", "confirmed", "fieldsNotRecorded"))
        if (!value.asJsonObject.get("startDate").isJsonNull) {
            validateDate(value.asJsonObject.get("startDate"), path + ".startDate")
        }
        if (!value.asJsonObject.get("endDateInclusive").isJsonNull) {
            validateDate(value.asJsonObject.get("endDateInclusive"), path + ".endDateInclusive")
        }
        if (!value.asJsonObject.get("timeZone").isJsonNull) {
            validateTimeZone(value.asJsonObject.get("timeZone"), path + ".timeZone")
        }
        if (!value.asJsonObject.get("confirmed").isJsonNull) {
            require(value.asJsonObject.get("confirmed").isJsonPrimitive && value.asJsonObject.get("confirmed").asJsonPrimitive.isBoolean) { path + ".confirmed" + " must be boolean." }
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateSourceScalar(value: JsonElement, path: String = "sourceScalar") {
        text(value, path, 0, 64)
        require(Regex("^-?(?:0|[1-9][0-9]{0,24})(?:\\.[0-9]{1,40})?(?:[eE][+-]?[0-9]{1,3})?\$").matches(value.asString)) { path + " has invalid text." }
    }

    fun validateProfileAdoption(value: JsonElement, path: String = "profileAdoption") {
        fields(value, path, setOf("id", "sourceProfileRef", "adoptedProfileRef", "sourcePeriodRef", "adoptedPeriodRef", "sourceWorkSnapshotRef", "adoptedWorkSnapshotRef", "sourceRuleRefs", "adoptedRuleRefs", "confirmedAtEpochSeconds", "confirmedFields", "fieldsNotRecorded"))
        validatePortableID(value.asJsonObject.get("id"), path + ".id")
        validatePortableID(value.asJsonObject.get("sourceProfileRef"), path + ".sourceProfileRef")
        validatePortableID(value.asJsonObject.get("adoptedProfileRef"), path + ".adoptedProfileRef")
        if (!value.asJsonObject.get("sourcePeriodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("sourcePeriodRef"), path + ".sourcePeriodRef")
        }
        if (!value.asJsonObject.get("adoptedPeriodRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("adoptedPeriodRef"), path + ".adoptedPeriodRef")
        }
        if (!value.asJsonObject.get("sourceWorkSnapshotRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("sourceWorkSnapshotRef"), path + ".sourceWorkSnapshotRef")
        }
        if (!value.asJsonObject.get("adoptedWorkSnapshotRef").isJsonNull) {
            validatePortableID(value.asJsonObject.get("adoptedWorkSnapshotRef"), path + ".adoptedWorkSnapshotRef")
        }
        array(value.asJsonObject.get("sourceRuleRefs"), path + ".sourceRuleRefs", 0, 100000, true)
        value.asJsonObject.get("sourceRuleRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".sourceRuleRefs" + "[]")
        }
        array(value.asJsonObject.get("adoptedRuleRefs"), path + ".adoptedRuleRefs", 0, 100000, true)
        value.asJsonObject.get("adoptedRuleRefs").asJsonArray.forEach { item ->
            validatePortableID(item, path + ".adoptedRuleRefs" + "[]")
        }
        validateEpochSeconds(value.asJsonObject.get("confirmedAtEpochSeconds"), path + ".confirmedAtEpochSeconds")
        array(value.asJsonObject.get("confirmedFields"), path + ".confirmedFields", 1, 64, true)
        value.asJsonObject.get("confirmedFields").asJsonArray.forEach { item ->
            validateConfirmedField(item, path + ".confirmedFields" + "[]")
        }
        validateNotRecorded(value.asJsonObject.get("fieldsNotRecorded"), path + ".fieldsNotRecorded")
    }

    fun validateConfirmedField(value: JsonElement, path: String = "confirmedField") {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isString && value.asString in setOf("name", "timeZone", "cadence", "cycleStartDate", "customEndDate", "currency", "hourlyRate", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "effectiveStartDate", "effectiveEndDateInclusive", "rounding", "weeklyOvertimeThreshold", "workweekStart", "currentWork", "periodWindow")) { path + " has an unsupported value." }
        text(value, path, 0, 100000000)
    }

    private val canonicalTimeZones = setOf("Africa/Abidjan", "Africa/Accra", "Africa/Addis_Ababa", "Africa/Algiers", "Africa/Asmara", "Africa/Asmera", "Africa/Bamako", "Africa/Bangui", "Africa/Banjul", "Africa/Bissau", "Africa/Blantyre", "Africa/Brazzaville", "Africa/Bujumbura", "Africa/Cairo", "Africa/Casablanca", "Africa/Ceuta", "Africa/Conakry", "Africa/Dakar", "Africa/Dar_es_Salaam", "Africa/Djibouti", "Africa/Douala", "Africa/El_Aaiun", "Africa/Freetown", "Africa/Gaborone", "Africa/Harare", "Africa/Johannesburg", "Africa/Juba", "Africa/Kampala", "Africa/Khartoum", "Africa/Kigali", "Africa/Kinshasa", "Africa/Lagos", "Africa/Libreville", "Africa/Lome", "Africa/Luanda", "Africa/Lubumbashi", "Africa/Lusaka", "Africa/Malabo", "Africa/Maputo", "Africa/Maseru", "Africa/Mbabane", "Africa/Mogadishu", "Africa/Monrovia", "Africa/Nairobi", "Africa/Ndjamena", "Africa/Niamey", "Africa/Nouakchott", "Africa/Ouagadougou", "Africa/Porto-Novo", "Africa/Sao_Tome", "Africa/Timbuktu", "Africa/Tripoli", "Africa/Tunis", "Africa/Windhoek", "America/Adak", "America/Anchorage", "America/Anguilla", "America/Antigua", "America/Araguaina", "America/Argentina/Buenos_Aires", "America/Argentina/Catamarca", "America/Argentina/ComodRivadavia", "America/Argentina/Cordoba", "America/Argentina/Jujuy", "America/Argentina/La_Rioja", "America/Argentina/Mendoza", "America/Argentina/Rio_Gallegos", "America/Argentina/Salta", "America/Argentina/San_Juan", "America/Argentina/San_Luis", "America/Argentina/Tucuman", "America/Argentina/Ushuaia", "America/Aruba", "America/Asuncion", "America/Atikokan", "America/Atka", "America/Bahia", "America/Bahia_Banderas", "America/Barbados", "America/Belem", "America/Belize", "America/Blanc-Sablon", "America/Boa_Vista", "America/Bogota", "America/Boise", "America/Buenos_Aires", "America/Cambridge_Bay", "America/Campo_Grande", "America/Cancun", "America/Caracas", "America/Catamarca", "America/Cayenne", "America/Cayman", "America/Chicago", "America/Chihuahua", "America/Ciudad_Juarez", "America/Coral_Harbour", "America/Cordoba", "America/Costa_Rica", "America/Coyhaique", "America/Creston", "America/Cuiaba", "America/Curacao", "America/Danmarkshavn", "America/Dawson", "America/Dawson_Creek", "America/Denver", "America/Detroit", "America/Dominica", "America/Edmonton", "America/Eirunepe", "America/El_Salvador", "America/Ensenada", "America/Fort_Nelson", "America/Fort_Wayne", "America/Fortaleza", "America/Glace_Bay", "America/Godthab", "America/Goose_Bay", "America/Grand_Turk", "America/Grenada", "America/Guadeloupe", "America/Guatemala", "America/Guayaquil", "America/Guyana", "America/Halifax", "America/Havana", "America/Hermosillo", "America/Indiana/Indianapolis", "America/Indiana/Knox", "America/Indiana/Marengo", "America/Indiana/Petersburg", "America/Indiana/Tell_City", "America/Indiana/Vevay", "America/Indiana/Vincennes", "America/Indiana/Winamac", "America/Indianapolis", "America/Inuvik", "America/Iqaluit", "America/Jamaica", "America/Jujuy", "America/Juneau", "America/Kentucky/Louisville", "America/Kentucky/Monticello", "America/Knox_IN", "America/Kralendijk", "America/La_Paz", "America/Lima", "America/Los_Angeles", "America/Louisville", "America/Lower_Princes", "America/Maceio", "America/Managua", "America/Manaus", "America/Marigot", "America/Martinique", "America/Matamoros", "America/Mazatlan", "America/Mendoza", "America/Menominee", "America/Merida", "America/Metlakatla", "America/Mexico_City", "America/Miquelon", "America/Moncton", "America/Monterrey", "America/Montevideo", "America/Montreal", "America/Montserrat", "America/Nassau", "America/New_York", "America/Nipigon", "America/Nome", "America/Noronha", "America/North_Dakota/Beulah", "America/North_Dakota/Center", "America/North_Dakota/New_Salem", "America/Nuuk", "America/Ojinaga", "America/Panama", "America/Pangnirtung", "America/Paramaribo", "America/Phoenix", "America/Port-au-Prince", "America/Port_of_Spain", "America/Porto_Acre", "America/Porto_Velho", "America/Puerto_Rico", "America/Punta_Arenas", "America/Rainy_River", "America/Rankin_Inlet", "America/Recife", "America/Regina", "America/Resolute", "America/Rio_Branco", "America/Rosario", "America/Santa_Isabel", "America/Santarem", "America/Santiago", "America/Santo_Domingo", "America/Sao_Paulo", "America/Scoresbysund", "America/Shiprock", "America/Sitka", "America/St_Barthelemy", "America/St_Johns", "America/St_Kitts", "America/St_Lucia", "America/St_Thomas", "America/St_Vincent", "America/Swift_Current", "America/Tegucigalpa", "America/Thule", "America/Thunder_Bay", "America/Tijuana", "America/Toronto", "America/Tortola", "America/Vancouver", "America/Virgin", "America/Whitehorse", "America/Winnipeg", "America/Yakutat", "America/Yellowknife", "Antarctica/Casey", "Antarctica/Davis", "Antarctica/DumontDUrville", "Antarctica/Macquarie", "Antarctica/Mawson", "Antarctica/McMurdo", "Antarctica/Palmer", "Antarctica/Rothera", "Antarctica/South_Pole", "Antarctica/Syowa", "Antarctica/Troll", "Antarctica/Vostok", "Arctic/Longyearbyen", "Asia/Aden", "Asia/Almaty", "Asia/Amman", "Asia/Anadyr", "Asia/Aqtau", "Asia/Aqtobe", "Asia/Ashgabat", "Asia/Ashkhabad", "Asia/Atyrau", "Asia/Baghdad", "Asia/Bahrain", "Asia/Baku", "Asia/Bangkok", "Asia/Barnaul", "Asia/Beirut", "Asia/Bishkek", "Asia/Brunei", "Asia/Calcutta", "Asia/Chita", "Asia/Choibalsan", "Asia/Chongqing", "Asia/Chungking", "Asia/Colombo", "Asia/Dacca", "Asia/Damascus", "Asia/Dhaka", "Asia/Dili", "Asia/Dubai", "Asia/Dushanbe", "Asia/Famagusta", "Asia/Gaza", "Asia/Harbin", "Asia/Hebron", "Asia/Ho_Chi_Minh", "Asia/Hong_Kong", "Asia/Hovd", "Asia/Irkutsk", "Asia/Istanbul", "Asia/Jakarta", "Asia/Jayapura", "Asia/Jerusalem", "Asia/Kabul", "Asia/Kamchatka", "Asia/Karachi", "Asia/Kashgar", "Asia/Kathmandu", "Asia/Katmandu", "Asia/Khandyga", "Asia/Kolkata", "Asia/Krasnoyarsk", "Asia/Kuala_Lumpur", "Asia/Kuching", "Asia/Kuwait", "Asia/Macao", "Asia/Macau", "Asia/Magadan", "Asia/Makassar", "Asia/Manila", "Asia/Muscat", "Asia/Nicosia", "Asia/Novokuznetsk", "Asia/Novosibirsk", "Asia/Omsk", "Asia/Oral", "Asia/Phnom_Penh", "Asia/Pontianak", "Asia/Pyongyang", "Asia/Qatar", "Asia/Qostanay", "Asia/Qyzylorda", "Asia/Rangoon", "Asia/Riyadh", "Asia/Saigon", "Asia/Sakhalin", "Asia/Samarkand", "Asia/Seoul", "Asia/Shanghai", "Asia/Singapore", "Asia/Srednekolymsk", "Asia/Taipei", "Asia/Tashkent", "Asia/Tbilisi", "Asia/Tehran", "Asia/Tel_Aviv", "Asia/Thimbu", "Asia/Thimphu", "Asia/Tokyo", "Asia/Tomsk", "Asia/Ujung_Pandang", "Asia/Ulaanbaatar", "Asia/Ulan_Bator", "Asia/Urumqi", "Asia/Ust-Nera", "Asia/Vientiane", "Asia/Vladivostok", "Asia/Yakutsk", "Asia/Yangon", "Asia/Yekaterinburg", "Asia/Yerevan", "Atlantic/Azores", "Atlantic/Bermuda", "Atlantic/Canary", "Atlantic/Cape_Verde", "Atlantic/Faeroe", "Atlantic/Faroe", "Atlantic/Jan_Mayen", "Atlantic/Madeira", "Atlantic/Reykjavik", "Atlantic/South_Georgia", "Atlantic/St_Helena", "Atlantic/Stanley", "Australia/ACT", "Australia/Adelaide", "Australia/Brisbane", "Australia/Broken_Hill", "Australia/Canberra", "Australia/Currie", "Australia/Darwin", "Australia/Eucla", "Australia/Hobart", "Australia/LHI", "Australia/Lindeman", "Australia/Lord_Howe", "Australia/Melbourne", "Australia/NSW", "Australia/North", "Australia/Perth", "Australia/Queensland", "Australia/South", "Australia/Sydney", "Australia/Tasmania", "Australia/Victoria", "Australia/West", "Australia/Yancowinna", "Brazil/Acre", "Brazil/DeNoronha", "Brazil/East", "Brazil/West", "CET", "CST6CDT", "Canada/Atlantic", "Canada/Central", "Canada/Eastern", "Canada/Mountain", "Canada/Newfoundland", "Canada/Pacific", "Canada/Saskatchewan", "Canada/Yukon", "Chile/Continental", "Chile/EasterIsland", "Cuba", "EET", "EST", "EST5EDT", "Egypt", "Eire", "Etc/GMT", "Etc/GMT+0", "Etc/GMT+1", "Etc/GMT+10", "Etc/GMT+11", "Etc/GMT+12", "Etc/GMT+2", "Etc/GMT+3", "Etc/GMT+4", "Etc/GMT+5", "Etc/GMT+6", "Etc/GMT+7", "Etc/GMT+8", "Etc/GMT+9", "Etc/GMT-0", "Etc/GMT-1", "Etc/GMT-10", "Etc/GMT-11", "Etc/GMT-12", "Etc/GMT-13", "Etc/GMT-14", "Etc/GMT-2", "Etc/GMT-3", "Etc/GMT-4", "Etc/GMT-5", "Etc/GMT-6", "Etc/GMT-7", "Etc/GMT-8", "Etc/GMT-9", "Etc/GMT0", "Etc/Greenwich", "Etc/UCT", "Etc/UTC", "Etc/Universal", "Etc/Zulu", "Europe/Amsterdam", "Europe/Andorra", "Europe/Astrakhan", "Europe/Athens", "Europe/Belfast", "Europe/Belgrade", "Europe/Berlin", "Europe/Bratislava", "Europe/Brussels", "Europe/Bucharest", "Europe/Budapest", "Europe/Busingen", "Europe/Chisinau", "Europe/Copenhagen", "Europe/Dublin", "Europe/Gibraltar", "Europe/Guernsey", "Europe/Helsinki", "Europe/Isle_of_Man", "Europe/Istanbul", "Europe/Jersey", "Europe/Kaliningrad", "Europe/Kiev", "Europe/Kirov", "Europe/Kyiv", "Europe/Lisbon", "Europe/Ljubljana", "Europe/London", "Europe/Luxembourg", "Europe/Madrid", "Europe/Malta", "Europe/Mariehamn", "Europe/Minsk", "Europe/Monaco", "Europe/Moscow", "Europe/Nicosia", "Europe/Oslo", "Europe/Paris", "Europe/Podgorica", "Europe/Prague", "Europe/Riga", "Europe/Rome", "Europe/Samara", "Europe/San_Marino", "Europe/Sarajevo", "Europe/Saratov", "Europe/Simferopol", "Europe/Skopje", "Europe/Sofia", "Europe/Stockholm", "Europe/Tallinn", "Europe/Tirane", "Europe/Tiraspol", "Europe/Ulyanovsk", "Europe/Uzhgorod", "Europe/Vaduz", "Europe/Vatican", "Europe/Vienna", "Europe/Vilnius", "Europe/Volgograd", "Europe/Warsaw", "Europe/Zagreb", "Europe/Zaporozhye", "Europe/Zurich", "Factory", "GB", "GB-Eire", "GMT", "GMT+0", "GMT-0", "GMT0", "Greenwich", "HST", "Hongkong", "Iceland", "Indian/Antananarivo", "Indian/Chagos", "Indian/Christmas", "Indian/Cocos", "Indian/Comoro", "Indian/Kerguelen", "Indian/Mahe", "Indian/Maldives", "Indian/Mauritius", "Indian/Mayotte", "Indian/Reunion", "Iran", "Israel", "Jamaica", "Japan", "Kwajalein", "Libya", "MET", "MST", "MST7MDT", "Mexico/BajaNorte", "Mexico/BajaSur", "Mexico/General", "NZ", "NZ-CHAT", "Navajo", "PRC", "PST8PDT", "Pacific/Apia", "Pacific/Auckland", "Pacific/Bougainville", "Pacific/Chatham", "Pacific/Chuuk", "Pacific/Easter", "Pacific/Efate", "Pacific/Enderbury", "Pacific/Fakaofo", "Pacific/Fiji", "Pacific/Funafuti", "Pacific/Galapagos", "Pacific/Gambier", "Pacific/Guadalcanal", "Pacific/Guam", "Pacific/Honolulu", "Pacific/Johnston", "Pacific/Kanton", "Pacific/Kiritimati", "Pacific/Kosrae", "Pacific/Kwajalein", "Pacific/Majuro", "Pacific/Marquesas", "Pacific/Midway", "Pacific/Nauru", "Pacific/Niue", "Pacific/Norfolk", "Pacific/Noumea", "Pacific/Pago_Pago", "Pacific/Palau", "Pacific/Pitcairn", "Pacific/Pohnpei", "Pacific/Ponape", "Pacific/Port_Moresby", "Pacific/Rarotonga", "Pacific/Saipan", "Pacific/Samoa", "Pacific/Tahiti", "Pacific/Tarawa", "Pacific/Tongatapu", "Pacific/Truk", "Pacific/Wake", "Pacific/Wallis", "Pacific/Yap", "Poland", "Portugal", "ROC", "ROK", "Singapore", "Turkey", "UCT", "US/Alaska", "US/Aleutian", "US/Arizona", "US/Central", "US/East-Indiana", "US/Eastern", "US/Hawaii", "US/Indiana-Starke", "US/Michigan", "US/Mountain", "US/Pacific", "US/Samoa", "UTC", "Universal", "W-SU", "WET", "Zulu")

    private fun fields(value: JsonElement, path: String, expected: Set<String>) {
        require(value.isJsonObject && value.asJsonObject.keySet() == expected) { "$path has missing or unknown fields." }
    }
    private fun text(value: JsonElement, path: String, minimum: Int, maximum: Int) {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isString && value.asString.length in minimum..maximum) { "$path must be bounded text." }
    }
    private fun integer(value: JsonElement, path: String, minimum: String?, maximum: String?) {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isNumber && value.asString.matches(Regex("-?(?:0|[1-9][0-9]*)")) && value.asBigDecimal.let { number -> (minimum == null || number >= java.math.BigDecimal(minimum)) && (maximum == null || number <= java.math.BigDecimal(maximum)) }) { "$path must be a supported exact integer." }
    }
    private fun array(value: JsonElement, path: String, minimum: Int, maximum: Int, unique: Boolean) {
        require(value.isJsonArray && value.asJsonArray.size() in minimum..maximum) { "$path must be a bounded collection." }
        require(!unique || value.asJsonArray.toList().toSet().size == value.asJsonArray.size()) { "$path contains duplicate values." }
    }
}
