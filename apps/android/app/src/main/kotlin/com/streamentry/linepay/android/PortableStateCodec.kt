package com.streamentry.linepay.android

import com.google.gson.GsonBuilder
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import java.math.BigDecimal
import java.security.MessageDigest
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/** Typed portable financial records, not an alternate native-state blob or a payroll reassessor. */
object AndroidPortableStateCodec {
    const val FORMAT = "com.streamentry.linepay.portable-state"
    private val recognizedWeeklyPendingReasons = setOf(
        "WEEKLY_REVIEW_PENDING",
        "A separate complete-workweek review is pending.",
        "Complete workweek coverage and any additional weekly premium are not mapped into this " +
            "paycheck comparison. A pay-period hour total or a separate weekly result does not " +
            "establish that mapping. Review the complete workweek before relying on the gross difference.",
    )
    private val gson = GsonBuilder().serializeNulls().disableHtmlEscaping().create()
    private val entityArrays = linkedMapOf("profile" to "profiles", "ruleSnapshot" to "ruleSnapshots",
        "ruleChange" to "ruleChanges", "ruleTimeline" to "ruleTimelines", "period" to "periods", "workSnapshot" to "workSnapshots", "paycheckReceipt" to "paycheckReceipts", "profileAdoption" to "adoptions", "attachment" to "attachments")

    fun decode(bytes: ByteArray): AndroidLocalState {
        val root = PortableStateJson.parse(bytes)
        preflight(root)
        val identities = mutableListOf<AndroidPortableLocalIdentity>()
        fun local(kind: String, portable: String): String = identities.singleOrNull { it.entityType == kind && it.portableID == portable }?.localID
            ?: UUID.nameUUIDFromBytes(("linepay.portable/" + kind + "/" + portable).toByteArray()).toString().also {
                identities += AndroidPortableLocalIdentity(kind, portable, it)
            }
        val defaultProfile = root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) }
        val currentPeriod = workingPeriod(root, defaultProfile)
        val profileRecord = workingProfile(root, currentPeriod, defaultProfile)
        val rule = profileRecord?.let { root.byID("ruleSnapshots", it.string("ruleRef")) }
        val candidateProfile = try {
            if (profileRecord == null || rule == null || listOf("timeZone", "cadence", "cycleStartDate").any { profileRecord.get(it).isJsonNull }) null else AndroidRuleProfile(
            id = local("profile", profileRecord.string("id")), version = rule.string("version"),
            hourlyRate = rule.string("hourlyRate"), currencyCode = rule.string("currency"),
            cadence = when (profileRecord.string("cadence")) {
                "weekly" -> PayCycleChoice.WEEKLY
                "biweekly" -> PayCycleChoice.BIWEEKLY
                "semimonthly" -> PayCycleChoice.SEMIMONTHLY
                else -> PayCycleChoice.CUSTOM
            },
            cycleStartDate = profileRecord.string("cycleStartDate"), customLastDate = profileRecord.optionalString("customEndDate"),
            payrollTimeZone = profileRecord.string("timeZone"),
            dailyOvertimeAfterHours = rule.objects("dailyOvertimeTiers").singleOrNull()?.string("afterHours"),
            dailyOvertimeMultiplier = rule.objects("dailyOvertimeTiers").singleOrNull()?.string("multiplier") ?: "1.5",
            outsideScheduleMultiplier = rule.optionalString("outsideScheduleMultiplier") ?: "1",
            perDiemPerWorkDate = rule.get("perDiemPerWorkDate").takeUnless { it.isJsonNull }?.asJsonObject?.string("amount"),
            // Source confirmation is evidence metadata, never independent legal verification.
            rulesReviewedByWorker = rule.get("confirmedByWorker").takeUnless { it.isJsonNull }?.asBoolean ?: false,
            hasIndependentEffectiveDates = true,
            effectiveStartDate = rule.optionalString("effectiveStartDate"), effectiveEndDateInclusive = rule.optionalString("effectiveEndDateInclusive"),
            requiresPortableRuleConfirmation = activationFields(root, profileRecord, rule).isNotEmpty(),
            importedSourceProfileRef = profileRecord.string("id"),
            calculationRuleID = rule.string("ruleID"),
            portableRuleFieldsNeedingConfirmation = activationFields(root, profileRecord, rule),
        ).also(AndroidLocalStateValidator::validateProfile)
        } catch (_: IllegalArgumentException) { null }
        val workRef = currentPeriod?.optionalString("currentWorkSnapshotRef") ?: profileRecord?.optionalString("currentWorkSnapshotRef")
        val candidateWork = workRef?.takeIf { candidateProfile != null }?.let { root.byID("workSnapshots", it).objects("work").map { item ->
            AndroidWorkEntry(local("workEntry", item.string("id")), item.get("startEpochSeconds").asLong,
                item.get("endEpochSeconds").asLong, item.string("timeZone"), item.objects("unpaidBreaks").map { entry ->
                    AndroidWorkBreak(local("workBreak", entry.string("id")), entry.get("startEpochSeconds").asLong, entry.get("endEpochSeconds").asLong)
                }, item.optionalString("note") ?: "")
        } }.orEmpty()
        val profile = candidateProfile?.takeIf { runCatching { candidateWork.forEach(AndroidLocalStateValidator::validateWork) }.isSuccess }
        val work = if (profile == null) emptyList() else candidateWork
        if (profileRecord != null && profile != null && rule != null) {
            identities += AndroidPortableLocalIdentity("ruleSnapshot", rule.string("id"), ruleKey(profile))
            if (workRef != null) identities += AndroidPortableLocalIdentity("workSnapshot", workRef, ledgerKey(profile, work))
        }
        val archive = AndroidPortableArchive(root.deepCopy(), identities.toList())
        return AndroidLocalState(profile = profile, work = work, portableArchive = archive).also(AndroidLocalStateValidator::validate)
    }

    fun encode(state: AndroidLocalState, exportedAtEpochSeconds: Long = java.time.Instant.now().epochSecond): ByteArray {
        AndroidLocalStateValidator.validate(state)
        require(state.weeklyReviews.isEmpty() && state.benefitReviews.isEmpty()) {
            "UNSUPPORTED_SOURCE_RECORD_KIND: Separate weekly and employer-contribution receipts cannot be represented by portable v1. No file was created. Use a complete Android-only backup instead."
        }
        val root = state.portableArchive?.document?.deepCopy() ?: obj(
            "format" to FORMAT, "version" to 1, "exportedAtEpochSeconds" to exportedAtEpochSeconds,
            "source" to obj("client" to "android", "localStateSchema" to 5, "exporterVersion" to "1"),
            "sourceInventory" to JsonObject(), "activeProfileRef" to null, "adoptions" to emptyList<Any>(), "identityCrosswalk" to emptyList<Any>(),
            "profiles" to emptyList<Any>(), "ruleSnapshots" to emptyList<Any>(), "ruleChanges" to emptyList<Any>(), "ruleTimelines" to emptyList<Any>(),
            "periods" to emptyList<Any>(), "workSnapshots" to emptyList<Any>(), "paycheckReceipts" to emptyList<Any>(), "attachments" to emptyList<Any>(),
        )
        root.addProperty("exportedAtEpochSeconds", exportedAtEpochSeconds)
        root.add("source", obj("client" to "android", "localStateSchema" to 5, "exporterVersion" to "1"))
        val mappings = state.portableArchive?.localIdentities.orEmpty()
        fun id(kind: String, local: String, derived: Boolean = false): String {
            val mapped = mappings.singleOrNull { it.entityType == kind && it.localID == local }?.portableID
            val result = mapped ?: "android." + kind + "." + UUID.nameUUIDFromBytes((kind + "/" + local).toByteArray())
            if (root.objects("identityCrosswalk").none { it.string("entityType") == kind && it.string("portableID") == result }) {
                root.getAsJsonArray("identityCrosswalk").add(obj("entityType" to kind, "portableID" to result, "originClient" to "android", "originKind" to if (derived) "derived" else "native", "originLocalID" to local))
            }
            return result
        }
        fun put(collection: String, value: JsonObject, replace: Boolean = false) {
            val array = root.getAsJsonArray(collection)
            val index = array.indexOfFirst { it.asJsonObject.string("id") == value.string("id") }
            if (index < 0) array.add(value) else if (replace) array.set(index, value)
        }
        fun rule(profile: AndroidRuleProfile): String {
            val key = ruleKey(profile)
            val ref = id("ruleSnapshot", key, true)
            if (root.objects("ruleSnapshots").any { it.string("id") == ref }) return ref
            require(profile.dailyOvertimeAfterHours != null || BigDecimal(profile.dailyOvertimeMultiplier).compareTo(BigDecimal("1.5")) == 0) {
                "UNSUPPORTED_SOURCE_DRAFT: A disabled daily overtime tier retains a nondefault draft multiplier. Portable v1 cannot omit that draft."
            }
            put("ruleSnapshots", obj("id" to ref, "ruleID" to (profile.calculationRuleID ?: profile.id), "version" to profile.version,
                "displayName" to null, "effectiveStartDate" to if (profile.hasIndependentEffectiveDates) profile.effectiveStartDate else profile.cycleStartDate,
                "effectiveEndDateInclusive" to profile.effectiveEndDateInclusive, "currency" to profile.currencyCode.uppercase(), "hourlyRate" to decimal(profile.hourlyRate),
                "regularSchedule" to emptyList<Any>(), "dailyOvertimeTiers" to profile.dailyOvertimeAfterHours?.let { listOf(obj("afterHours" to decimal(it), "multiplier" to decimal(profile.dailyOvertimeMultiplier))) }.orEmpty(),
                "outsideScheduleMultiplier" to decimal(profile.outsideScheduleMultiplier), "weekdayPremiums" to emptyList<Any>(), "datePremiums" to emptyList<Any>(),
                "calloutMinimumHours" to null, "perDiemPerWorkDate" to profile.perDiemPerWorkDate?.let { money(it, profile.currencyCode) },
                "weeklyOvertime" to null, "rounding" to obj("scope" to "payCategory", "scale" to 2, "mode" to "halfUp"),
                "sources" to null, "unsupportedRuleNotes" to null, "confirmedAtEpochSeconds" to null, "confirmedByWorker" to profile.rulesReviewedByWorker,
                "fieldsNotRecorded" to listOf("displayName", "sources", "unsupportedRuleNotes", "confirmedAtEpochSeconds")))
            return ref
        }
        fun work(profileRef: String, periodRef: String?, role: String, key: String, entries: List<AndroidWorkEntry>): String {
            val ref = id("workSnapshot", key, true)
            if (root.objects("workSnapshots").any { it.string("id") == ref }) return ref
            val work = entries.map { entry -> obj("id" to id("workEntry", entry.id), "startEpochSeconds" to entry.startEpochSeconds,
                "endEpochSeconds" to entry.endEpochSeconds, "timeZone" to entry.timeZone, "kind" to "regular", "calloutEventRef" to null,
                "unpaidBreaks" to entry.breaks.map { item -> obj("id" to id("workBreak", item.id), "startEpochSeconds" to item.startEpochSeconds, "endEpochSeconds" to item.endEpochSeconds) },
                "note" to entry.note, "fieldsNotRecorded" to emptyList<Any>()) }
            put("workSnapshots", obj("id" to ref, "profileRef" to profileRef, "periodRef" to periodRef, "role" to role,
                "revision" to null, "sourceRef" to null, "work" to work, "fieldsNotRecorded" to listOf("revision", "sourceRef")))
            return ref
        }
        fun currentPeriod(profile: AndroidRuleProfile, owner: String, ruleRef: String, workRef: String, key: String): String {
            val window = LinePaycheckRepository.payWindow(profile)
            val ref = id("period", key, true)
            val windowRef = id("periodWindow", "window:" + key, true)
            val record = obj("id" to ref, "profileRef" to owner,
                "calendarWindow" to obj("startDate" to window.startDate.toString(), "endDateInclusive" to window.lastDate.toString(),
                    "endExclusiveDate" to window.endExclusiveDate.toString(), "timeZone" to window.timeZone.id, "boundaryModel" to "localDatesOnly",
                    "startEpochSeconds" to null, "endExclusiveEpochSeconds" to null, "fieldsNotRecorded" to listOf("startEpochSeconds", "endExclusiveEpochSeconds")),
                "cadence" to cadence(profile.cadence), "isCurrent" to true, "closed" to null, "archivedAtEpochSeconds" to null,
                "calculationIssue" to null, "ruleRef" to ruleRef, "ruleChangeRefs" to emptyList<Any>(), "currentWorkSnapshotRef" to workRef,
                "workSnapshotRefs" to listOf(workRef), "workCorrections" to emptyList<Any>(), "windowRef" to windowRef,
                "ruleTimelineRefs" to emptyList<Any>(), "calculation" to null, "auditCompletedAtEpochSeconds" to null, "workRevision" to null,
                "fieldsNotRecorded" to listOf("closed", "archivedAtEpochSeconds", "calculationIssue", "calculation", "auditCompletedAtEpochSeconds", "workRevision"))
            put("periods", record)
            return ref
        }
        val active = state.profile
        val profileRef = active?.takeUnless { it.requiresPortableRuleConfirmation }?.let { id("profile", it.id) }
        if (active != null && profileRef != null && !active.requiresPortableRuleConfirmation) {
            val ruleRef = rule(active)
            val ledgerRef = work(profileRef, null, "currentLedger", ledgerKey(active, state.work), state.work)
            val prior = root.objects("profiles").singleOrNull { it.string("id") == profileRef }
            val record = prior?.deepCopy() ?: obj("id" to profileRef, "name" to null, "timeZone" to active.payrollTimeZone,
                "cadence" to cadence(active.cadence), "cycleStartDate" to active.cycleStartDate, "customEndDate" to active.customLastDate,
                "ruleRef" to ruleRef, "baselineRuleRef" to ruleRef, "ruleChangeRefs" to emptyList<Any>(), "currentPeriodRef" to null,
                "currentWorkSnapshotRef" to ledgerRef, "adoptedFromProfileRef" to null, "fieldsNotRecorded" to listOf("name", "currentPeriodRef"))
            record.addProperty("timeZone", active.payrollTimeZone); record.addProperty("cadence", prior?.optionalString("cadence")?.takeIf { nativeCadence(it) == cadence(active.cadence) } ?: cadence(active.cadence))
            record.addProperty("cycleStartDate", active.cycleStartDate); record.add("customEndDate", gson.toJsonTree(active.customLastDate))
            record.addProperty("ruleRef", ruleRef); record.addProperty("currentWorkSnapshotRef", ledgerRef)
            put("profiles", record, replace = true)
            if (active.importedSourceProfileRef != null && "unsupportedCurrentWork" !in active.portableRuleFieldsNeedingConfirmation.orEmpty()) workingPeriod(root, root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) })?.let { selected ->
                if (selected.optionalString("profileRef") == profileRef) {
                    if (!selected.get("calculation").isJsonNull && selected.optionalString("currentWorkSnapshotRef") != ledgerRef) {
                        val nextPeriodRef = currentPeriod(active, profileRef, ruleRef, ledgerRef, "current-input:" + ledgerKey(active, state.work))
                        root.objects("periods").forEach { period ->
                            if (period.get("isCurrent").takeUnless { it.isJsonNull }?.asBoolean == true) period.addProperty("isCurrent", period.string("id") == nextPeriodRef)
                        }
                        record.addProperty("currentPeriodRef", nextPeriodRef)
                        record.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
                        put("profiles", record, replace = true)
                    } else {
                        selected.addProperty("currentWorkSnapshotRef", ledgerRef)
                        selected.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentWorkSnapshotRef"))
                        if (selected.getAsJsonArray("workSnapshotRefs").none { it.asString == ledgerRef }) selected.getAsJsonArray("workSnapshotRefs").add(ledgerRef)
                    }
                }
            }
            if (state.portableArchive == null || active.useAsFutureDefault || root.optionalString("activeProfileRef") == null && active.importedSourceProfileRef == null && state.portableArchive.localAdoptions.none { it.adoptedProfile.id == active.id }) root.addProperty("activeProfileRef", profileRef)
            state.portableArchive?.localAdoptions.orEmpty().filter { it.adoptedProfile.id == active.id }.forEach { adoption ->
                val adoptedRuleRef = rule(adoption.adoptedProfile)
                val adoptedWorkRef = work(profileRef, null, "currentLedger", ledgerKey(adoption.adoptedProfile, adoption.adoptedWork), adoption.adoptedWork)
                val adoptedPeriodRef = currentPeriod(adoption.adoptedProfile, profileRef, adoptedRuleRef, adoptedWorkRef, "adoption-period:" + active.id)
                val currentPeriodRef = if (adoption.adoptedProfile == active && adoption.adoptedWork == state.work) adoptedPeriodRef
                    else currentPeriod(active, profileRef, ruleRef, ledgerRef, "current-period:" + active.id + ":" + digest(gson.toJson(listOf(active.cadence.name, active.cycleStartDate, active.customLastDate, active.payrollTimeZone, active.version))))
                root.objects("periods").forEach { period ->
                    if (period.get("isCurrent").takeUnless { it.isJsonNull }?.asBoolean == true) period.addProperty("isCurrent", period.string("id") == currentPeriodRef)
                }
                record.addProperty("currentPeriodRef", currentPeriodRef)
                record.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
                if (active.useAsFutureDefault) root.addProperty("activeProfileRef", profileRef)
                record.addProperty("baselineRuleRef", adoptedRuleRef)
                record.addProperty("adoptedFromProfileRef", adoption.sourceProfileRef)
                put("profiles", record, replace = true)
                val adoptionRef = id("profileAdoption", "adoption:" + active.id, true)
                put("adoptions", obj("id" to adoptionRef, "sourceProfileRef" to adoption.sourceProfileRef, "adoptedProfileRef" to profileRef,
                    "sourcePeriodRef" to adoption.sourcePeriodRef, "adoptedPeriodRef" to adoptedPeriodRef,
                    "sourceWorkSnapshotRef" to adoption.sourceWorkSnapshotRef, "adoptedWorkSnapshotRef" to adoptedWorkRef,
                    "sourceRuleRefs" to adoption.sourceRuleRefs, "adoptedRuleRefs" to listOf(adoptedRuleRef),
                    "confirmedAtEpochSeconds" to adoption.confirmedAtEpochSeconds, "confirmedFields" to adoption.confirmedFields,
                    "fieldsNotRecorded" to emptyList<Any>()))
            }
        }
        require(state.work.isEmpty() || active != null) { "Work has no active profile context; portable export refused." }
        require(active?.requiresPortableRuleConfirmation != true || state.checks.isEmpty()) { "Unconfirmed source rules cannot own native paycheck comparisons." }
        for (check in state.checks) {
            require(profileRef != null) { "Historical paycheck receipt has no profile context." }
            val ruleRef = rule(check.profile)
            val ownerProfileRef = id("profile", check.profile.id)
            if (root.objects("profiles").none { it.string("id") == ownerProfileRef }) {
                put("profiles", obj("id" to ownerProfileRef, "name" to null, "timeZone" to check.profile.payrollTimeZone,
                    "cadence" to cadence(check.profile.cadence), "cycleStartDate" to check.profile.cycleStartDate, "customEndDate" to check.profile.customLastDate,
                    "ruleRef" to ruleRef, "baselineRuleRef" to ruleRef, "ruleChangeRefs" to emptyList<Any>(), "currentPeriodRef" to null,
                    "currentWorkSnapshotRef" to null, "adoptedFromProfileRef" to null,
                    "fieldsNotRecorded" to listOf("name", "currentPeriodRef", "currentWorkSnapshotRef")))
            }
            val receiptRef = id("paycheckReceipt", check.id)
            val periodRef = id("period", "check-period:" + check.id, true)
            val snapshotRef = work(ownerProfileRef, periodRef, "paycheckInput", "check-work:" + check.id, check.work)
            put("periods", obj("id" to periodRef, "profileRef" to ownerProfileRef,
                "calendarWindow" to calendarRecord(check.targetStartDate, check.targetLastDate, check.payrollTimeZone),
                "cadence" to cadence(check.profile.cadence), "isCurrent" to null, "closed" to null,
                "archivedAtEpochSeconds" to null, "calculationIssue" to null, "ruleRef" to ruleRef,
                "ruleChangeRefs" to emptyList<Any>(), "currentWorkSnapshotRef" to null, "workSnapshotRefs" to listOf(snapshotRef),
                "workCorrections" to emptyList<Any>(), "windowRef" to id("periodWindow", "check-window:" + check.id, true),
                "ruleTimelineRefs" to emptyList<Any>(), "calculation" to null, "auditCompletedAtEpochSeconds" to null, "workRevision" to null,
                "fieldsNotRecorded" to listOf("isCurrent", "closed", "currentWorkSnapshotRef", "archivedAtEpochSeconds", "calculationIssue", "calculation", "auditCompletedAtEpochSeconds", "workRevision")))
            val nativeComponentIDs = check.components.mapIndexedNotNull { index, component -> component.id?.let { index to it } }.toMap().toMutableMap()
            require(check.components.all { it.id != null } || check.comparisons.isEmpty() || check.engine == "linepay.android.configured-lines/1") {
                "UNREPRESENTABLE_COMPONENT_REFERENCES: Legacy component order is not proven for this source engine/version."
            }
            check.comparisons.forEach { comparison ->
                val indexes = check.components.indices.filter { index -> comparison.field == "PER_DIEM_PAY" && check.components[index].category == "PER_DIEM" || comparison.field == "GROSS_PAY" && (check.grossBasis == GrossBasisChoice.WAGES_AND_PER_DIEM || check.components[index].category != "PER_DIEM") }
                require(indexes.size == comparison.componentIds.size) { "UNREPRESENTABLE_COMPONENT_REFERENCES: Native receipt references do not match its retained component order." }
                indexes.zip(comparison.componentIds).forEach { (index, originalID) ->
                    require(nativeComponentIDs[index] == null || nativeComponentIDs[index] == originalID) { "Conflicting native component references." }
                    nativeComponentIDs[index] = originalID
                }
            }
            require(nativeComponentIDs.values.toSet().size == nativeComponentIDs.size) { "UNREPRESENTABLE_COMPONENT_REFERENCES: Legacy comparison IDs ambiguously name more than one component." }
            val componentRefs = check.components.indices.associateWith { index -> id("calculationComponent", nativeComponentIDs[index] ?: "check-component:${check.id}:$index", nativeComponentIDs[index] == null) }
            val components = check.components.mapIndexed { index, component ->
                require(component.agreementId == (check.profile.calculationRuleID ?: check.profile.id) && component.agreementVersion == check.profile.version) { "Unsupported historical rule reference." }
                obj("id" to componentRefs.getValue(index), "category" to when (component.category) { "PER_DIEM" -> "perDiem"; "WORKED_HOURS" -> "workedHours"; else -> throw InvalidLocalState("UNSUPPORTED_CALCULATION_COMPONENT: ${component.category}") },
                    "workRef" to component.workId?.let { id("workEntry", it) }, "localDate" to component.date, "hours" to null, "workedSeconds" to component.seconds?.let(::decimal),
                    "multiplier" to component.multiplier?.let(::decimal), "amount" to money(component.amount, component.currencyCode), "explanation" to component.explanation,
                    "ruleKeys" to component.ruleKeys, "baseRate" to null,
                    "appliedAgreement" to obj("ruleRef" to ruleRef, "ruleID" to component.agreementId, "version" to component.agreementVersion, "hourlyRate" to null),
                    "unroundedAmount" to null, "baseTimeNumerator" to null, "fieldsNotRecorded" to (listOf("hours", "baseRate", "unroundedAmount", "baseTimeNumerator") + if (component.id == null && component.workId == null) listOf("workRef") else emptyList()))
            }
            val captured = check.confirmedLineFacts
            val observed = linkedMapOf(
                "regularHours" to captured?.regularHours, "regularPay" to captured?.regularPay,
                "overtimeHours" to captured?.overtimeHours, "overtimePay" to captured?.overtimePay,
                "doubleTimeHours" to captured?.doubleTimeHours, "doubleTimePay" to captured?.doubleTimePay,
                "calloutPay" to captured?.calloutPay, "perDiemPay" to captured?.paidPerDiem,
            )
            val missingPaystub = observed.filterValues { it == null }.keys + listOf("notes", "confirmedAtEpochSeconds", "evidenceRef", "confirmed")
            val paystub = obj("id" to id("paystub", "check-paystub:" + check.id, true), "periodStartDate" to check.sourceStartDate, "periodEndDateInclusive" to check.sourceLastDate,
                "currency" to check.profile.currencyCode.uppercase(), "grossPay" to if (captured == null) decimal(check.paidGross) else check.paidGross,
                "regularHours" to observed["regularHours"], "regularPay" to observed["regularPay"],
                "overtimeHours" to observed["overtimeHours"], "overtimePay" to observed["overtimePay"],
                "doubleTimeHours" to observed["doubleTimeHours"], "doubleTimePay" to observed["doubleTimePay"], "calloutPay" to observed["calloutPay"],
                "perDiemPay" to observed["perDiemPay"], "notes" to null, "confirmedAtEpochSeconds" to null, "evidenceRef" to null, "confirmed" to null, "fieldsNotRecorded" to missingPaystub)
            val portableLines = if (captured == null) obj("grossBasis" to canonicalEnum(check.grossBasis.name), "lineLayout" to null, "hoursBasis" to null, "guaranteeLayout" to null,
                "amounts" to null, "hours" to null, "reviewedFields" to null, "suggestions" to null,
                "hasAdditionalUnmappedPay" to null, "workComplete" to null, "earningsLinesComplete" to null,
                "fieldsNotRecorded" to listOf("lineLayout", "hoursBasis", "guaranteeLayout", "amounts", "hours", "reviewedFields", "suggestions", "hasAdditionalUnmappedPay", "workComplete", "earningsLinesComplete"))
            else obj("grossBasis" to canonicalEnum(check.grossBasis.name), "lineLayout" to canonicalEnum(captured.layout),
                "hoursBasis" to canonicalEnum(captured.hoursBasis), "guaranteeLayout" to canonicalEnum(captured.guaranteeLayout),
                "amounts" to captured.amounts().map { (field, value) -> obj("field" to canonicalEnum(field.name), "amount" to obj("amount" to value, "currency" to check.profile.currencyCode.uppercase())) },
                "hours" to captured.hours().map { (field, value) -> obj("field" to canonicalEnum(field.name), "hours" to value) },
                "reviewedFields" to (listOf("grossPay") + observed.filterValues { it != null }.keys), "suggestions" to null,
                "hasAdditionalUnmappedPay" to null, "workComplete" to check.completeWorkConfirmed, "earningsLinesComplete" to captured.completeEarningsLines,
                "fieldsNotRecorded" to listOf("suggestions", "hasAdditionalUnmappedPay"))
            val lineScope = captured != null && check.comparisons.any { it.field !in setOf("GROSS_PAY", "PER_DIEM_PAY") }
            val comparisons = check.comparisons.map { comparison -> obj("id" to comparison.field, "field" to canonicalEnum(comparison.field),
                "expected" to decimal(comparison.expected), "paid" to decimal(comparison.paid), "difference" to decimal(comparison.difference),
                "unit" to canonicalEnum(comparison.unit), "currency" to comparison.currencyCode,
                "componentRefs" to comparison.componentIds.map { original -> id("calculationComponent", original) }) }
            val receipt = obj("receiptKind" to "paycheck-v1", "id" to receiptRef, "periodRef" to periodRef,
                "workSnapshotRef" to snapshotRef, "createdAtEpochSeconds" to check.createdAtEpochSeconds, "supersedesReceiptRef" to null,
                "producer" to obj("client" to "android", "localStateSchema" to null, "calculationEngineID" to null, "calculationEngineVersion" to null,
                    "assessmentEngineID" to check.engine, "assessmentEngineVersion" to null, "fieldsNotRecorded" to listOf("localStateSchema", "calculationEngineID", "calculationEngineVersion", "assessmentEngineVersion")),
                "ruleRefs" to listOf(ruleRef), "sourcePeriod" to obj("startDate" to check.sourceStartDate, "endDateInclusive" to check.sourceLastDate, "timeZone" to check.sourceTimeZone, "confirmed" to check.sourcePeriodConfirmed, "fieldsNotRecorded" to emptyList<Any>()),
                "paystubFacts" to paystub,
                "lineFacts" to portableLines,
                "reviewFacts" to obj("completeWorkConfirmed" to check.completeWorkConfirmed, "ruleCoverageConfirmed" to check.ruleCoverageConfirmed,
                    "unreviewedFields" to if (captured != null) !check.sourcePeriodConfirmed else null,
                    "weeklyReviewPending" to if (captured != null || "WEEKLY_REVIEW_PENDING" in check.reviewReasons) true else null,
                    "fieldsNotRecorded" to (
                        (if (captured == null) listOf("unreviewedFields") else emptyList<String>()) +
                            (if (captured == null && "WEEKLY_REVIEW_PENDING" !in check.reviewReasons) listOf("weeklyReviewPending") else emptyList())
                    ),
                ),
                "calculation" to if (components.isEmpty()) null else obj("agreementID" to (check.profile.calculationRuleID ?: check.profile.id), "agreementVersion" to check.profile.version,
                    "primaryRuleRef" to ruleRef, "agreementSnapshotRefs" to listOf(ruleRef), "currency" to check.profile.currencyCode.uppercase(), "total" to null,
                    "provenance" to null, "weeklyRegularRate" to null, "components" to components,
                    "engine" to null, "coverage" to null, "wages" to null, "allowances" to null, "ruleTimelineRef" to null, "ruleChangeRefs" to emptyList<Any>(),
                    "fieldsNotRecorded" to listOf("total", "provenance", "weeklyRegularRate", "engine", "coverage", "wages", "allowances", "ruleTimelineRef")),
                "assessment" to obj("engineID" to check.engine, "engineVersion" to null, "verdict" to canonicalEnum(check.verdict), "scope" to if (lineScope) "confirmedLines" else "grossOnly",
                    "expectedGross" to check.expectedGross?.let { money(it, check.profile.currencyCode) }, "paidGross" to money(check.paidGross, check.profile.currencyCode),
                    "difference" to check.difference?.let { money(it, check.profile.currencyCode) }, "comparisons" to comparisons,
                    "reviewReasons" to check.reviewReasons, "scopeNotes" to listOf(check.coverage), "weeklyContextCount" to null,
                    "weeklyReviewRefs" to emptyList<Any>(), "periodMatch" to canonicalEnum(check.periodMatch),
                    "reportedPeriod" to obj("startDate" to check.sourceStartDate, "endDateInclusive" to check.sourceLastDate, "timeZone" to check.sourceTimeZone, "confirmed" to check.sourcePeriodConfirmed, "fieldsNotRecorded" to emptyList<Any>()),
                    "fieldsNotRecorded" to listOf("engineVersion", "weeklyContextCount")),
                "targetWindowRef" to id("periodWindow", "check-window:" + check.id, true), "targetWindow" to calendarRecord(check.targetStartDate, check.targetLastDate, check.payrollTimeZone),
                "targetCadence" to cadence(check.profile.cadence), "targetRuleChangeRefs" to emptyList<Any>(),
                "reconciliation" to null, "attachmentRefs" to emptyList<Any>(), "auditRevisionRef" to null, "fieldsNotRecorded" to listOf("supersedesReceiptRef", "reconciliation", "auditRevisionRef"))
            put("paycheckReceipts", receipt)
        }
        val counts = obj("profileCount" to root.objects("profiles").size, "ruleSnapshotCount" to root.objects("ruleSnapshots").size,
            "ruleChangeCount" to root.objects("ruleChanges").size, "ruleTimelineCount" to root.objects("ruleTimelines").size, "periodCount" to root.objects("periods").size,
            "workSnapshotCount" to root.objects("workSnapshots").size, "workEntryCount" to root.objects("workSnapshots").sumOf { it.objects("work").size },
            "workBreakCount" to root.objects("workSnapshots").sumOf { snapshot -> snapshot.objects("work").sumOf { it.objects("unpaidBreaks").size } },
            "workCorrectionCount" to root.objects("periods").sumOf { it.objects("workCorrections").size },
            "calculationComponentCount" to calculations(root).sumOf { it.objects("components").size },
            "adoptionCount" to root.objects("adoptions").size,
            "workweekCount" to calculations(root).count { !it.get("weeklyRegularRate").isJsonNull },
            "weeklyAllocationCount" to calculations(root).sumOf { it.get("weeklyRegularRate").takeUnless { value -> value.isJsonNull }?.asJsonObject?.objects("allocations")?.size ?: 0 },
            "periodWindowCount" to (root.objects("periods").map { it.string("windowRef") } + root.objects("paycheckReceipts").map { it.string("targetWindowRef") }).toSet().size,
            "auditRevisionCount" to root.objects("paycheckReceipts").count { !it.get("auditRevisionRef").isJsonNull },
            "paycheckReceiptCount" to root.objects("paycheckReceipts").size, "attachmentCount" to root.objects("attachments").size,
            "unsupportedFinancialRecordKinds" to emptyList<Any>(), "unsupportedDraftKinds" to emptyList<Any>(), "omittedFinancialRecordCount" to 0)
        root.add("sourceInventory", counts)
        preflight(root)
        return gson.toJson(root).toByteArray(Charsets.UTF_8)
    }

    fun adopt(state: AndroidLocalState, confirmed: AndroidRuleProfile, confirmedAtEpochSeconds: Long = java.time.Instant.now().epochSecond, startNewWorkLedger: Boolean = false): AndroidLocalState {
        val prior = state.profile
        val archive = requireNotNull(state.portableArchive)
        require((prior == null && sourceProfileForReview(state) != null || prior?.requiresPortableRuleConfirmation == true || prior?.importedSourceProfileRef != null) && !confirmed.requiresPortableRuleConfirmation && confirmed.importedSourceProfileRef == null && confirmed.calculationRuleID == null && confirmed.rulesReviewedByWorker && confirmed.portableRuleFieldsNeedingConfirmation.orEmpty().isEmpty() && confirmed.id != prior?.id) {
            "Adoption requires a separately confirmed new native profile."
        }
        require(!requiresSeparateNativeLedger(state) || startNewWorkLedger) { "Imported work remains in its original source context. Explicitly start a separate empty native work ledger; original source work stays retained." }
        val adoptedWork = if (startNewWorkLedger) emptyList() else state.work
        AndroidLocalStateValidator.validateProfile(confirmed)
        require(confirmedAtEpochSeconds in 946684800..4102444799L) { "Unsupported adoption date." }
        val defaultRef = archive.document.optionalString("activeProfileRef")
        val sourceProfile = requireNotNull(sourceProfileForReview(state))
        val sourceRef = sourceProfile.string("id")
        val currentPeriod = workingPeriod(archive.document, defaultRef?.let { archive.document.byID("profiles", it) })
        val consultedRules = (listOfNotNull(sourceProfile.string("ruleRef"), sourceProfile.optionalString("baselineRuleRef"), currentPeriod?.optionalString("ruleRef")) +
            defaultRef?.let { archive.document.byID("profiles", it) }?.let { listOfNotNull(it.string("ruleRef"), it.optionalString("baselineRuleRef")) }.orEmpty()).distinct()
        val event = AndroidPortableAdoption(sourceRef, currentPeriod?.string("id"),
            currentPeriod?.optionalString("currentWorkSnapshotRef") ?: sourceProfile.optionalString("currentWorkSnapshotRef"), consultedRules,
            confirmed.useAsFutureDefault, confirmed.copy(), adoptedWork.map { it.copy(breaks = it.breaks.toList()) }, confirmedAtEpochSeconds,
            (prior?.portableRuleFieldsNeedingConfirmation.orEmpty().filter { it in setOf("timeZone", "cadence", "cycleStartDate", "customEndDate", "currency", "hourlyRate", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "effectiveStartDate", "effectiveEndDateInclusive", "rounding", "periodWindow") } + listOf("timeZone", "cadence", "cycleStartDate", "currency", "hourlyRate", "dailyOvertimeTiers", "outsideScheduleMultiplier", "perDiemPerWorkDate", "effectiveStartDate", "effectiveEndDateInclusive", "rounding", "currentWork", "periodWindow")).distinct())
        return state.copy(profile = confirmed.copy(), work = adoptedWork, portableArchive = archive.copy(localAdoptions = archive.localAdoptions + event))
            .also(AndroidLocalStateValidator::validate)
    }

    /** A source-owned active configuration cannot be silently edited into a new native rule. */
    fun validateCurrentSourceProfile(state: AndroidLocalState) {
        val profile = state.profile ?: return
        val sourceRef = profile.importedSourceProfileRef ?: return
        val archive = requireNotNull(state.portableArchive) { "Imported rule provenance is missing." }
        require(archive.localIdentities.any { it.entityType == "profile" && it.portableID == sourceRef && it.localID == profile.id }) { "Imported profile lost its identity mapping." }
        val source = archive.document.byID("profiles", sourceRef)
        val rule = archive.document.byID("ruleSnapshots", source.string("ruleRef"))
        val missing = activationFields(archive.document, source, rule)
        require(profile.requiresPortableRuleConfirmation == missing.isNotEmpty() && profile.portableRuleFieldsNeedingConfirmation.orEmpty().toSet() == missing.toSet()) { "Imported rule confirmation state contradicts retained source evidence." }
        fun same(first: String?, second: String?) = if (first == null || second == null) first == second else BigDecimal(first).compareTo(BigDecimal(second)) == 0
        val tier = rule.objects("dailyOvertimeTiers").singleOrNull()
        require(profile.payrollTimeZone == source.string("timeZone") && cadence(profile.cadence) == nativeCadence(source.string("cadence")) && profile.cycleStartDate == source.string("cycleStartDate") && profile.customLastDate == source.optionalString("customEndDate")) { "Imported pay-cycle changes require a separate confirmed profile." }
        require(profile.calculationRuleID == rule.string("ruleID") && profile.version == rule.string("version") && profile.currencyCode == rule.string("currency") && same(profile.hourlyRate, rule.string("hourlyRate")) &&
            same(profile.dailyOvertimeAfterHours, tier?.string("afterHours")) && same(profile.dailyOvertimeMultiplier, tier?.string("multiplier") ?: "1.5") &&
            same(profile.outsideScheduleMultiplier, rule.optionalString("outsideScheduleMultiplier") ?: "1") &&
            same(profile.perDiemPerWorkDate, rule.get("perDiemPerWorkDate").takeUnless { it.isJsonNull }?.asJsonObject?.string("amount")) &&
            profile.hasIndependentEffectiveDates && profile.effectiveStartDate == rule.optionalString("effectiveStartDate") && profile.effectiveEndDateInclusive == rule.optionalString("effectiveEndDateInclusive") &&
            profile.rulesReviewedByWorker == (rule.get("confirmedByWorker").takeUnless { it.isJsonNull }?.asBoolean ?: false)) { "Imported rule changes require a separate confirmed profile; original source facts remain unchanged." }
    }

    fun validateArchive(archive: AndroidPortableArchive) {
        preflight(archive.document)
        require(archive.localIdentities.size <= 100_000) { "Too many portable identity mappings." }
        require(archive.localIdentities.map { it.entityType to it.portableID }.toSet().size == archive.localIdentities.size) { "Duplicate portable identity mapping." }
        require(archive.localIdentities.map { it.entityType to it.localID }.toSet().size == archive.localIdentities.size) { "Conflicting local identity mapping." }
        val ids = collectIDs(archive.document)
        require(archive.localAdoptions.size <= 1000 && archive.localAdoptions.map { it.adoptedProfile.id }.toSet().size == archive.localAdoptions.size) { "Invalid local adoption lineage." }
        archive.localAdoptions.forEach { adoption ->
            require(archive.document.objects("profiles").any { it.string("id") == adoption.sourceProfileRef }) { "Adoption source profile was not retained." }
            require(adoption.confirmedAtEpochSeconds in 946684800..4102444799L && adoption.confirmedFields.size in 1..64 && adoption.confirmedFields.none { it.length !in 1..100 }) { "Invalid adoption confirmation." }
            AndroidLocalStateValidator.validateProfile(adoption.adoptedProfile)
            require(!adoption.adoptedProfile.requiresPortableRuleConfirmation && adoption.adoptedProfile.rulesReviewedByWorker) { "Adoption does not retain a confirmed native profile." }
            adoption.adoptedWork.forEach(AndroidLocalStateValidator::validateWork)
        }
        archive.localIdentities.forEach {
            require((it.entityType to it.portableID) in ids && it.localID.isNotBlank() && it.localID.length <= 512) { "Invalid local portable identity mapping." }
        }
    }

    /** Validate every record and capability before producing any replacement state or preview. */
    fun preflight(root: JsonObject) {
        PortableStateShape.validateDocument(root)
        checkMarkers(root)
        require(root.toString().toByteArray().size <= PortableStateJson.MAXIMUM_FINANCIAL_BYTES) { "Portable financial data exceeds the supported size." }
        require(root.objects("attachments").isEmpty()) { "UNSUPPORTED_ATTACHMENTS: Android cannot retain original attachments. The entire file was refused." }
        require(root.optionalString("activeProfileRef")?.let { id -> root.objects("profiles").count { it.string("id") == id } == 1 } != false) { "Invalid active profile identity." }
        workingPeriod(root, root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) })
        val inventory = root.getAsJsonObject("sourceInventory")
        require(inventory.getAsJsonArray("unsupportedFinancialRecordKinds").isEmpty && inventory.getAsJsonArray("unsupportedDraftKinds").isEmpty) { "UNSUPPORTED_SOURCE_RECORD_KIND: This file contains unsupported financial records or drafts." }
        for ((field, array) in listOf("profileCount" to "profiles", "ruleSnapshotCount" to "ruleSnapshots", "ruleChangeCount" to "ruleChanges", "ruleTimelineCount" to "ruleTimelines", "adoptionCount" to "adoptions", "periodCount" to "periods", "workSnapshotCount" to "workSnapshots", "paycheckReceiptCount" to "paycheckReceipts", "attachmentCount" to "attachments")) {
            require(inventory.get(field).asBigDecimal.compareTo(BigDecimal(root.getAsJsonArray(array).size())) == 0) { "Source inventory does not match $array." }
        }
        require(inventory.get("workEntryCount").asBigDecimal.compareTo(BigDecimal(root.objects("workSnapshots").sumOf { it.objects("work").size })) == 0) { "Source work inventory does not match the retained snapshots." }
        val allCalculations = root.objects("periods").mapNotNull { it.get("calculation").takeUnless { value -> value.isJsonNull }?.asJsonObject } +
            root.objects("paycheckReceipts").mapNotNull { it.get("calculation").takeUnless { value -> value.isJsonNull }?.asJsonObject }
        val extraCounts = mapOf(
            "workBreakCount" to root.objects("workSnapshots").sumOf { snapshot -> snapshot.objects("work").sumOf { it.objects("unpaidBreaks").size } },
            "workCorrectionCount" to root.objects("periods").sumOf { it.objects("workCorrections").size },
            "calculationComponentCount" to allCalculations.sumOf { it.objects("components").size },
            "workweekCount" to allCalculations.count { !it.get("weeklyRegularRate").isJsonNull },
            "weeklyAllocationCount" to allCalculations.sumOf { it.get("weeklyRegularRate").takeUnless { value -> value.isJsonNull }?.asJsonObject?.objects("allocations")?.size ?: 0 },
            "auditRevisionCount" to root.objects("paycheckReceipts").count { !it.get("auditRevisionRef").isJsonNull },
            "periodWindowCount" to root.objects("identityCrosswalk").count { it.string("entityType") == "periodWindow" },
        )
        extraCounts.forEach { (name, count) -> require(inventory.get(name).asBigDecimal.compareTo(BigDecimal(count)) == 0) { "Source inventory does not match $name." } }
        val ids = collectIDs(root)
        val crosswalk = root.objects("identityCrosswalk")
        require(crosswalk.map { it.string("portableID") }.toSet().size == crosswalk.size) { "Duplicate source identity crosswalk." }
        val nativeOrigins = crosswalk.filter { it.string("originKind") == "native" }
        require(nativeOrigins.all { !it.get("originLocalID").isJsonNull } && nativeOrigins.map { Triple(it.string("entityType"), it.string("originClient"), it.string("originLocalID")) }.toSet().size == nativeOrigins.size) { "Duplicate or missing native source identity." }
        require(crosswalk.map { it.string("entityType") to it.string("portableID") }.toSet() == ids) { "Source crosswalk is incomplete or contains unknown records." }
        fun ref(kind: String, id: String?) { if (id != null) require((kind to id) in ids) { "Dangling $kind reference: $id." } }
        fun refs(kind: String, values: JsonElement?) {
            values?.takeUnless { it.isJsonNull }?.asJsonArray?.forEach { ref(kind, it.asString) }
        }
        ref("profile", root.optionalString("activeProfileRef"))
        val adoptedProfiles = mutableSetOf<String>()
        val confirmedFields = setOf("name", "timeZone", "cadence", "cycleStartDate", "customEndDate", "currency", "hourlyRate", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "effectiveStartDate", "effectiveEndDateInclusive", "rounding", "weeklyOvertimeThreshold", "workweekStart", "currentWork", "periodWindow")
        root.objects("adoptions").forEach { adoption ->
            val sourceRef = adoption.string("sourceProfileRef"); val adoptedRef = adoption.string("adoptedProfileRef")
            ref("profile", sourceRef); ref("profile", adoptedRef)
            require(sourceRef != adoptedRef && adoptedProfiles.add(adoptedRef)) { "Invalid or duplicate adoption lineage." }
            val adopted = root.byID("profiles", adoptedRef)
            require(adopted.optionalString("adoptedFromProfileRef") == sourceRef) { "Adopted profile lost its source lineage." }
            require(adoption.getAsJsonArray("confirmedFields").all { it.asString in confirmedFields }) { "Adoption cannot confirm legal or weekly applicability." }
            for ((prefix, owner) in listOf("source" to sourceRef, "adopted" to adoptedRef)) {
                val periodRef = adoption.optionalString(prefix + "PeriodRef")
                ref("period", periodRef)
                if (periodRef != null) require(root.byID("periods", periodRef).optionalString("profileRef").let { it == owner || prefix == "source" && it == null }) { "Adoption period belongs to a different profile." }
                val workRef = adoption.optionalString(prefix + "WorkSnapshotRef")
                ref("workSnapshot", workRef)
                if (workRef != null) require(root.byID("workSnapshots", workRef).string("profileRef") == owner) { "Adoption work belongs to a different profile." }
                refs("ruleSnapshot", adoption.getAsJsonArray(prefix + "RuleRefs"))
            }
            val baseline = adopted.optionalString("baselineRuleRef") ?: adopted.string("ruleRef")
            require(adoption.getAsJsonArray("adoptedRuleRefs").any { it.asString == baseline }) { "Adoption lost its original confirmed rule." }
        }
        root.objects("ruleSnapshots").forEach { rule ->
            val start = rule.optionalString("effectiveStartDate")?.let(::date)
            val end = rule.optionalString("effectiveEndDateInclusive")?.let(::date)
            require(start == null || end == null || end >= start) { "Reversed rule effective dates." }
            val perDiem = rule.get("perDiemPerWorkDate")
            if (!perDiem.isJsonNull) require(perDiem.asJsonObject.string("currency") == rule.string("currency")) { "Per-diem currency mismatch." }
            rule.get("sources").takeUnless { it.isJsonNull }?.asJsonArray?.forEach { source ->
                ref("attachment", source.asJsonObject.optionalString("documentRef"))
                require(source.asJsonObject.get("documentRef").isJsonNull) { "UNSUPPORTED_ATTACHMENTS: Source original cannot be retained." }
            }
        }
        root.objects("profiles").forEach { profile ->
            ref("ruleSnapshot", profile.string("ruleRef")); ref("ruleSnapshot", profile.optionalString("baselineRuleRef"))
            ref("profile", profile.optionalString("adoptedFromProfileRef"))
            require(profile.optionalString("adoptedFromProfileRef") == null || profile.string("id") in adoptedProfiles) { "Missing profile adoption receipt." }
            profile.optionalString("currentWorkSnapshotRef")?.let { id ->
                val snapshot = root.byID("workSnapshots", id)
                require(snapshot.string("role") == "currentLedger" && snapshot.string("profileRef") == profile.string("id")) { "Current work snapshot belongs to another profile or role." }
            }
            profile.optionalString("timeZone")?.let(::zone); profile.optionalString("cycleStartDate")?.let(::date)
            ref("period", profile.optionalString("currentPeriodRef")); ref("workSnapshot", profile.optionalString("currentWorkSnapshotRef"))
            refs("ruleChange", profile.getAsJsonArray("ruleChangeRefs"))
        }
        val frozenWindows = mutableMapOf<String, Pair<JsonObject, String?>>()
        fun frozenWindow(id: String, window: JsonObject, cadence: String?) {
            val facts = window to cadence
            require(frozenWindows.putIfAbsent(id, facts)?.let { it == facts } != false) { "One period-window identity describes conflicting frozen boundaries or cadence." }
        }
        root.objects("paycheckReceipts").forEach { receipt -> frozenWindow(receipt.string("targetWindowRef"), receipt.getAsJsonObject("targetWindow"), receipt.optionalString("targetCadence")) }
        root.objects("periods").forEach { period ->
            frozenWindow(period.string("windowRef"), period.getAsJsonObject("calendarWindow"), period.optionalString("cadence"))
            ref("profile", period.optionalString("profileRef")); ref("ruleSnapshot", period.optionalString("ruleRef"))
            refs("workSnapshot", period.getAsJsonArray("workSnapshotRefs")); refs("ruleChange", period.getAsJsonArray("ruleChangeRefs"))
            ref("workSnapshot", period.optionalString("currentWorkSnapshotRef"))
            period.getAsJsonArray("workSnapshotRefs").forEach { snapshotID ->
                require(root.byID("workSnapshots", snapshotID.asString).optionalString("periodRef")?.let { it == period.string("id") } != false) { "A period references a different period's work snapshot." }
            }
            period.optionalString("currentWorkSnapshotRef")?.let { snapshotID -> require(root.byID("workSnapshots", snapshotID).string("role") in setOf("currentLedger", "periodRevision")) { "Invalid role for a period's current work snapshot." } }
            refs("ruleTimeline", period.getAsJsonArray("ruleTimelineRefs"))
            calendar(period.getAsJsonObject("calendarWindow"))
            period.objects("workCorrections").forEach { ref("workSnapshot", it.string("workSnapshotRef")) }
            period.get("calculation").takeUnless { it.isJsonNull }?.asJsonObject?.let { calculation ->
                val sourceWorkIDs = period.optionalString("currentWorkSnapshotRef")?.let { root.byID("workSnapshots", it).objects("work").map { work -> work.string("id") }.toSet() }.orEmpty()
                calculation.objects("components").forEach { component -> require(component.optionalString("workRef")?.let { it in sourceWorkIDs } != false) { "Period calculation references work outside its selected current snapshot." } }
            }
        }
        root.objects("workSnapshots").forEach { snapshot ->
            ref("profile", snapshot.string("profileRef")); ref("period", snapshot.optionalString("periodRef"))
            snapshot.optionalString("sourceRef")?.let { sourceID -> require(ids.any { it.second == sourceID }) { "Work snapshot lost its source identity." } }
            require(snapshot.objects("work").size <= AndroidLocalState.MAXIMUM_WORK_ENTRIES) { "Too many work entries." }
            require(snapshot.objects("work").map { it.string("id") }.toSet().size == snapshot.objects("work").size) { "Duplicate work identity inside one snapshot." }
            val breaks = snapshot.objects("work").flatMap { it.objects("unpaidBreaks") }
            require(breaks.map { it.string("id") }.toSet().size == breaks.size) { "Duplicate break identity inside one snapshot." }
            var previousEnd: Long? = null
            val sorted = snapshot.objects("work").sortedBy { it.get("startEpochSeconds").asLong }
            sorted.forEach { work ->
                zone(work.string("timeZone"))
                val start = work.get("startEpochSeconds").asLong; val end = work.get("endEpochSeconds").asLong
                require(end > start && (previousEnd == null || start >= previousEnd)) { "Work overlaps or has invalid boundaries." }
                previousEnd = end
                var breakEnd = start
                var unpaidSeconds = 0L
                work.objects("unpaidBreaks").sortedBy { it.get("startEpochSeconds").asLong }.forEach { item ->
                    require(item.get("startEpochSeconds").asLong >= breakEnd && item.get("endEpochSeconds").asLong <= end && item.get("endEpochSeconds").asLong > item.get("startEpochSeconds").asLong) { "Break is outside work or overlaps." }
                    breakEnd = item.get("endEpochSeconds").asLong
                    unpaidSeconds += item.get("endEpochSeconds").asLong - item.get("startEpochSeconds").asLong
                }
                require(unpaidSeconds < end - start) { "UNSUPPORTED_WORK: No worked time remains after unpaid breaks." }
            }
        }
        root.objects("ruleChanges").forEach { change ->
            ref("profile", change.optionalString("profileRef")); ref("profile", change.optionalString("sourceProfileRef"))
            ref("period", change.optionalString("periodRef")); ref("ruleSnapshot", change.string("ruleRef"))
            date(change.string("effectiveDate")) // Future configuration belongs to source history even beyond the present window.
        }
        root.objects("ruleTimelines").forEach { timeline ->
            ref("period", timeline.string("periodRef")); ref("ruleSnapshot", timeline.optionalString("baselineRuleRef"))
            refs("ruleChange", timeline.getAsJsonArray("ruleChangeRefs"))
            timeline.getAsJsonArray("ruleChangeRefs").forEach { changeRef -> require(root.byID("ruleChanges", changeRef.asString).optionalString("periodRef")?.let { it == timeline.string("periodRef") } != false) { "Timeline references a different period's rule change." } }
        }
        allCalculations.forEach { calculation ->
            ref("ruleSnapshot", calculation.optionalString("primaryRuleRef")); refs("ruleSnapshot", calculation.getAsJsonArray("agreementSnapshotRefs"))
            ref("ruleTimeline", calculation.optionalString("ruleTimelineRef")); refs("ruleChange", calculation.getAsJsonArray("ruleChangeRefs"))
            val componentIDs = calculation.objects("components").map { it.string("id") }
            require(componentIDs.toSet().size == componentIDs.size) { "Duplicate component identity inside a frozen calculation." }
            calculation.objects("components").forEach { component ->
                ref("workEntry", component.optionalString("workRef"))
                component.get("appliedAgreement").takeUnless { it.isJsonNull }?.asJsonObject?.let { applied ->
                    ref("ruleSnapshot", applied.string("ruleRef"))
                    val sourceRule = root.byID("ruleSnapshots", applied.string("ruleRef"))
                    require(applied.string("ruleID") == sourceRule.string("ruleID") && applied.string("version") == sourceRule.string("version")) { "Frozen component rule ID/version does not match its snapshot." }
                }
            }
            calculation.get("weeklyRegularRate").takeUnless { it.isJsonNull }?.asJsonObject?.let { weekly ->
                ref("workweek", weekly.string("workweekID")); require(weekly.objects("allocations").map { it.string("id") }.toSet().size == weekly.objects("allocations").size) { "Duplicate weekly allocation identity." }; weekly.objects("allocations").forEach { ref("period", it.optionalString("periodRef")) }
                weekly.optionalString("timeZone")?.let(::zone)
            }
        }
        root.objects("paycheckReceipts").forEach { receipt ->
            ref("period", receipt.optionalString("periodRef")); ref("workSnapshot", receipt.string("workSnapshotRef"))
            ref("paycheckReceipt", receipt.optionalString("supersedesReceiptRef")); refs("ruleSnapshot", receipt.getAsJsonArray("ruleRefs"))
            refs("attachment", receipt.getAsJsonArray("attachmentRefs"))
            receipt.get("sourcePeriod").takeUnless { it.isJsonNull }?.asJsonObject?.let { source ->
                val start = source.optionalString("startDate")?.let(::date)
                val last = source.optionalString("endDateInclusive")?.let(::date)
                require((start == null) == (last == null) && (start == null || last!! >= start)) { "Invalid statement dates." }
                source.optionalString("timeZone")?.let(::zone)
                if (source.get("confirmed").takeUnless { it.isJsonNull }?.asBoolean == true) require(start != null && source.optionalString("timeZone") != null) { "Confirmed source period is incomplete." }
            }
            calendar(receipt.getAsJsonObject("targetWindow"))
            refs("ruleChange", receipt.getAsJsonArray("targetRuleChangeRefs"))
            val assessment = receipt.getAsJsonObject("assessment")
            val reported = assessment.get("reportedPeriod").takeUnless { it.isJsonNull }?.asJsonObject
            val periodMatch = assessment.optionalString("periodMatch")
            if (periodMatch == "confirmedSamePeriod") {
                require(reported != null && reported.get("confirmed").takeUnless { it.isJsonNull }?.asBoolean == true &&
                    listOf("startDate", "endDateInclusive", "timeZone").all { reported.get(it) == receipt.getAsJsonObject("targetWindow").get(it) }) { "Confirmed source period does not match the target window." }
            }
            if (periodMatch == "differentPeriod") require(reported?.get("confirmed")?.takeUnless { it.isJsonNull }?.asBoolean == true) { "Different-period assessment lacks confirmed source dates." }
            if (periodMatch == "unconfirmedPeriod") require(reported?.get("confirmed")?.takeUnless { it.isJsonNull }?.asBoolean != true) { "Unconfirmed-period assessment contradicts confirmed source dates." }
            val review = receipt.getAsJsonObject("reviewFacts")
            val recognizedPendingReason = assessment.getAsJsonArray("reviewReasons").any { it.asString in recognizedWeeklyPendingReasons }
            val weeklyPending = review.get("weeklyReviewPending").takeUnless { it.isJsonNull }?.asBoolean
            if (weeklyPending == true) {
                require(assessment.string("verdict") in setOf("needsReview", "notComparable") && (assessment.string("verdict") != "needsReview" || recognizedPendingReason)) { "A pending weekly review cannot become a clean match or lose its established source reason." }
            }
            require(weeklyPending != false || !recognizedPendingReason) { "An established pending weekly reason contradicts a cleared pending flag." }
            val receiptWorkIDs = root.byID("workSnapshots", receipt.string("workSnapshotRef")).objects("work").map { it.string("id") }.toSet()
            val calculation = receipt.get("calculation")
            if (!calculation.isJsonNull) {
                val value = calculation.asJsonObject
                ref("ruleSnapshot", value.optionalString("primaryRuleRef")); refs("ruleSnapshot", value.getAsJsonArray("agreementSnapshotRefs"))
                val neededRules = (listOfNotNull(value.optionalString("primaryRuleRef")) + value.getAsJsonArray("agreementSnapshotRefs").map { it.asString } +
                    value.objects("components").mapNotNull { it.get("appliedAgreement").takeUnless { item -> item.isJsonNull }?.asJsonObject?.string("ruleRef") }).toSet()
                require(receipt.getAsJsonArray("ruleRefs").map { it.asString }.toSet().containsAll(neededRules)) { "Receipt omits a rule used by its frozen calculation." }
                require(receipt.getAsJsonArray("targetRuleChangeRefs").map { it.asString }.toSet().containsAll(value.getAsJsonArray("ruleChangeRefs").map { it.asString })) { "Receipt omits a rule change used by its calculation." }
                value.objects("components").forEach { component ->
                    ref("workEntry", component.optionalString("workRef")); date(component.string("localDate"))
                    require(component.optionalString("workRef")?.let { it in receiptWorkIDs } != false) { "Calculation component refers to work outside its own frozen receipt snapshot." }
                    component.get("appliedAgreement").takeUnless { it.isJsonNull }?.asJsonObject?.let { ref("ruleSnapshot", it.string("ruleRef")) }
                }
            }
            val componentIDs = if (calculation.isJsonNull) emptySet() else calculation.asJsonObject.objects("components").map { it.string("id") }.toSet()
            assessment.objects("comparisons").forEach { comparison ->
                require(comparison.getAsJsonArray("componentRefs").all { it.asString in componentIDs }) { "Comparison references a different receipt's component." }
            }
            refs("workweek", assessment.get("weeklyReviewRefs"))
        }
    }

    private fun collectIDs(root: JsonObject): Set<Pair<String, String>> {
        val found = linkedMapOf<Pair<String, String>, JsonObject>()
        fun add(kind: String, value: JsonObject) {
            val key = kind to value.string("id")
            val previous = found.putIfAbsent(key, value)
            require(previous == null || (kind in setOf("workEntry", "workBreak", "calculationComponent", "paystub", "periodWindow", "auditRevision", "workweek", "weeklyAllocation"))) { "Duplicate or conflicting $kind identity." }
        }
        entityArrays.forEach { (kind, name) -> root.objects(name).forEach { add(kind, it) } }
        root.objects("workSnapshots").forEach { it.objects("work").forEach { work -> add("workEntry", work); work.objects("unpaidBreaks").forEach { entry -> add("workBreak", entry) } } }
        calculations(root).forEach { calculation ->
            calculation.objects("components").forEach { add("calculationComponent", it) }
            calculation.get("weeklyRegularRate").takeUnless { it.isJsonNull }?.asJsonObject?.let { weekly ->
                add("workweek", obj("id" to weekly.string("workweekID")))
                weekly.objects("allocations").forEach { add("weeklyAllocation", it) }
            }
        }
        root.objects("periods").forEach { period ->
            add("periodWindow", obj("id" to period.string("windowRef")))
            period.objects("workCorrections").forEach { item -> add("workCorrection", item) }
        }
        root.objects("paycheckReceipts").forEach { receipt ->
            add("paystub", obj("id" to receipt.getAsJsonObject("paystubFacts").string("id")))
            add("periodWindow", obj("id" to receipt.string("targetWindowRef")))
            receipt.optionalString("auditRevisionRef")?.let { add("auditRevision", obj("id" to it)) }
        }
        return found.keys
    }

    private fun calendar(window: JsonObject) {
        val start = window.optionalString("startDate")?.let(::date)
        val last = window.optionalString("endDateInclusive")?.let(::date)
        val exclusive = window.optionalString("endExclusiveDate")?.let(::date)
        val timeZone = window.optionalString("timeZone")?.let(::zone)
        require((start == null) == (last == null) && (start == null || last!! >= start) && (exclusive == null || last == null || exclusive == last.plusDays(1))) { "Invalid frozen calendar boundaries." }
        if (window.string("boundaryModel") == "exactInstants") {
            require(start != null && last != null && timeZone != null && !window.get("startEpochSeconds").isJsonNull && !window.get("endExclusiveEpochSeconds").isJsonNull) { "Exact period has incomplete instants." }
            val first = java.time.Instant.ofEpochSecond(window.get("startEpochSeconds").asLong).atZone(timeZone)
            val end = java.time.Instant.ofEpochSecond(window.get("endExclusiveEpochSeconds").asLong).atZone(timeZone)
            require(first.toLocalDate() == start && end.toLocalDate() == last.plusDays(1) && first.toEpochSecond() == start.atStartOfDay(timeZone).toEpochSecond() && end.toEpochSecond() == last.plusDays(1).atStartOfDay(timeZone).toEpochSecond() && end.toEpochSecond() > first.toEpochSecond()) { "Period instants do not match its recorded local dates." }
        } else require(window.get("startEpochSeconds").isJsonNull && window.get("endExclusiveEpochSeconds").isJsonNull) { "Date-only period must not claim exact instants." }
    }

    fun sourceProfileForReview(state: AndroidLocalState): JsonObject? {
        val root = state.portableArchive?.document ?: return null
        state.profile?.importedSourceProfileRef?.let { return root.byID("profiles", it) }
        if (state.profile != null) return null
        val savedDefault = root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) }
        return workingProfile(root, workingPeriod(root, savedDefault), savedDefault)
    }

    fun requiresSeparateNativeLedger(state: AndroidLocalState): Boolean {
        val issues = state.profile?.portableRuleFieldsNeedingConfirmation.orEmpty()
        if ("unsupportedCurrentWork" in issues || "noCurrentWorkspace" in issues && state.work.isNotEmpty()) return true
        if (state.profile != null) return false
        val root = state.portableArchive?.document ?: return false
        val profile = sourceProfileForReview(state) ?: return false
        val period = workingPeriod(root, root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) })
        val snapshot = period?.optionalString("currentWorkSnapshotRef") ?: profile.optionalString("currentWorkSnapshotRef")
        return snapshot?.let { root.byID("workSnapshots", it).objects("work").isNotEmpty() } == true
    }

    private fun workingProfile(root: JsonObject, period: JsonObject?, savedDefault: JsonObject?): JsonObject? {
        val owner = period?.optionalString("profileRef") ?: period?.optionalString("currentWorkSnapshotRef")?.let { root.byID("workSnapshots", it).string("profileRef") }
        return owner?.let { root.byID("profiles", it) } ?: savedDefault
    }

    private fun workingPeriod(root: JsonObject, savedDefault: JsonObject?): JsonObject? {
        val knownCurrent = root.objects("periods").filter { it.get("isCurrent").takeUnless { value -> value.isJsonNull }?.asBoolean == true }
        require(knownCurrent.size <= 1) { "UNSUPPORTED_CURRENT_CONTEXT: More than one known-current period needs an explicit context picker. The whole file was refused." }
        return knownCurrent.singleOrNull() ?: savedDefault?.optionalString("currentPeriodRef")?.let { root.byID("periods", it) }
            ?.takeIf { it.get("isCurrent").isJsonNull && it.get("closed").takeUnless { value -> value.isJsonNull }?.asBoolean != true }
    }

    private fun activationFields(root: JsonObject, source: JsonObject, rule: JsonObject): List<String> {
        val missing = missingRuleFields(rule).toMutableList()
        for (field in listOf("regularSchedule", "weekdayPremiums", "datePremiums")) if (!rule.get(field).isJsonNull && !rule.getAsJsonArray(field).isEmpty) missing += field
        for (field in listOf("calloutMinimumHours", "weeklyOvertime")) if (!rule.get(field).isJsonNull) missing += field
        if (rule.objects("dailyOvertimeTiers").size > 1) missing += "dailyOvertimeTiers"
        rule.get("rounding").takeUnless { it.isJsonNull }?.asJsonObject?.let {
            if (it.string("scope") != "payCategory" || it.get("scale").asInt != 2 || it.string("mode") != "halfUp") missing += "rounding"
        }
        val selected = workingPeriod(root, root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) })
        val snapshotRef = selected?.optionalString("currentWorkSnapshotRef") ?: source.optionalString("currentWorkSnapshotRef")
        if (snapshotRef?.let { root.byID("workSnapshots", it).objects("work").any { work -> work.string("kind") != "regular" || !work.get("calloutEventRef").isJsonNull } } == true) missing += "unsupportedCurrentWork"
        if (!source.getAsJsonArray("ruleChangeRefs").isEmpty) missing += "periodRuleSelection"
        source.optionalString("currentPeriodRef")?.let { id ->
            val context = root.byID("periods", id)
            if (selected == null && (context.get("isCurrent").takeUnless { it.isJsonNull }?.asBoolean == false || context.get("closed").takeUnless { it.isJsonNull }?.asBoolean == true)) missing += "noCurrentWorkspace"
        }
        workingPeriod(root, root.optionalString("activeProfileRef")?.let { root.byID("profiles", it) })?.let { period ->
            val window = period.getAsJsonObject("calendarWindow")
            val configured = runCatching {
                com.streamentry.linepay.domain.CalendarPaycycle.window(
                    when (nativeCadence(source.string("cadence"))) {
                        "weekly" -> com.streamentry.linepay.domain.CalendarPaycycleCadence.WEEKLY
                        "biweekly" -> com.streamentry.linepay.domain.CalendarPaycycleCadence.BIWEEKLY
                        "semimonthly" -> com.streamentry.linepay.domain.CalendarPaycycleCadence.SEMIMONTHLY
                        else -> com.streamentry.linepay.domain.CalendarPaycycleCadence.MANUAL
                    }, date(source.string("cycleStartDate")), source.optionalString("customEndDate")?.let(::date), zone(source.string("timeZone")),
                )
            }.getOrNull()
            if (configured == null || window.optionalString("startDate") != configured.startDate.toString() ||
                window.optionalString("endDateInclusive") != configured.lastDate.toString() || window.optionalString("timeZone") != configured.timeZone.id ||
                period.optionalString("cadence")?.let { nativeCadence(it) != nativeCadence(source.string("cadence")) } == true) missing += "periodWindow"
            if (period.optionalString("profileRef")?.let { it != source.string("id") } == true) missing += "currentWorkProfileSelection"
            if (period.optionalString("ruleRef")?.let { it != source.string("ruleRef") } == true ||
                !period.getAsJsonArray("ruleChangeRefs").isEmpty || !period.getAsJsonArray("ruleTimelineRefs").isEmpty) missing += "periodRuleSelection"
        }
        return missing.distinct()
    }

    private fun nativeCadence(value: String) = if (value == "manual") "custom" else value

    private fun missingRuleFields(rule: JsonObject): List<String> {
        val critical = setOf("effectiveStartDate", "effectiveEndDateInclusive", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "weeklyOvertime", "rounding")
        val marked = rule.getAsJsonArray("fieldsNotRecorded").map { it.asString }.filter { it in critical }
        val requiredSemantics = listOf("rounding", "dailyOvertimeTiers", "outsideScheduleMultiplier", "regularSchedule", "weekdayPremiums", "datePremiums").filter { rule.get(it).isJsonNull }
        return (marked + requiredSemantics).distinct()
    }

    private fun obj(vararg fields: Pair<String, Any?>): JsonObject = JsonObject().apply { fields.forEach { (name, value) -> add(name, gson.toJsonTree(value)) } }
    private fun money(amount: String, currency: String) = obj("amount" to decimal(amount), "currency" to currency.uppercase())
    private fun decimal(value: String) = BigDecimal(value).stripTrailingZeros().toPlainString()
    private fun cadence(value: PayCycleChoice) = canonicalEnum(value.name)
    private fun canonicalEnum(value: String) = value.lowercase().split('_').mapIndexed { index, part -> if (index == 0) part else part.replaceFirstChar { it.uppercase() } }.joinToString("")
    private fun calendarRecord(start: String?, last: String?, timeZone: String?): JsonObject = obj(
        "startDate" to start, "endDateInclusive" to last, "endExclusiveDate" to null, "timeZone" to timeZone,
        "boundaryModel" to if (start == null) "sourcePeriodUnknown" else "localDatesOnly",
        "startEpochSeconds" to null, "endExclusiveEpochSeconds" to null,
        "fieldsNotRecorded" to listOf("endExclusiveDate", "startEpochSeconds", "endExclusiveEpochSeconds"),
    )

    private fun checkMarkers(value: JsonElement) {
        if (value.isJsonObject) {
            val item = value.asJsonObject
            item.get("fieldsNotRecorded")?.asJsonArray?.forEach { marker ->
                var field: JsonElement? = item
                marker.asString.split('.').forEach { key -> field = field?.takeIf { it.isJsonObject }?.asJsonObject?.get(key) }
                require(field != null && field.isJsonNull) { "A not-recorded field marker contradicts the source data." }
            }
            item.entrySet().filter { it.key != "fieldsNotRecorded" }.forEach { checkMarkers(it.value) }
        } else if (value.isJsonArray) value.asJsonArray.forEach(::checkMarkers)
    }

    private fun calculations(root: JsonObject): List<JsonObject> =
        (root.objects("periods") + root.objects("paycheckReceipts")).mapNotNull { it.get("calculation").takeUnless { value -> value.isJsonNull }?.asJsonObject }

    private fun date(value: String) = LocalDate.parse(value)
    private fun zone(value: String): ZoneId { require(value in ZoneId.getAvailableZoneIds()) { "Portable v1 requires a supported IANA time zone." }; return ZoneId.of(value) }
    private fun ruleKey(profile: AndroidRuleProfile) = "rule:" + digest(gson.toJson(obj(
        "id" to profile.id, "calculationRuleID" to (profile.calculationRuleID ?: profile.id), "version" to profile.version, "hourlyRate" to decimal(profile.hourlyRate), "currency" to profile.currencyCode.uppercase(),
        "tierAfter" to profile.dailyOvertimeAfterHours?.let(::decimal), "tierMultiplier" to decimal(profile.dailyOvertimeMultiplier),
        "outsideMultiplier" to decimal(profile.outsideScheduleMultiplier), "perDiem" to profile.perDiemPerWorkDate?.let(::decimal),
        "effectiveStart" to if (profile.hasIndependentEffectiveDates) profile.effectiveStartDate else profile.cycleStartDate,
        "effectiveEnd" to profile.effectiveEndDateInclusive, "confirmedByWorker" to profile.rulesReviewedByWorker)))
    private fun ledgerKey(profile: AndroidRuleProfile, work: List<AndroidWorkEntry>) = "ledger:" + profile.id + ":" + digest(gson.toJson(work))
    private fun digest(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
    private fun JsonObject.string(key: String) = get(key).asString
    private fun JsonObject.optionalString(key: String): String? = get(key)?.takeUnless { it.isJsonNull }?.asString
    private fun JsonObject.objects(key: String): List<JsonObject> = get(key)?.takeIf { it.isJsonArray }?.asJsonArray?.map { it.asJsonObject }.orEmpty()
    private fun JsonObject.byID(collection: String, id: String) = objects(collection).singleOrNull { it.string("id") == id } ?: throw InvalidLocalState("Missing or ambiguous $collection reference: $id.")
}
