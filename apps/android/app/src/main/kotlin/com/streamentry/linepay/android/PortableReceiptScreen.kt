package com.streamentry.linepay.android

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import com.google.gson.JsonElement
import com.google.gson.JsonObject

@Composable
fun PortableReceiptHistory(archive: AndroidPortableArchive?, onOpen: (String) -> Unit) {
    if (archive == null) return
    val receipts = archive.document.getAsJsonArray("paycheckReceipts")
    if (receipts.isEmpty) return
    SectionHeading("Imported paycheck receipts")
    Text("Original results remain unchanged. Importing does not resolve their review questions.")
    receipts.forEach { item ->
        val receipt = item.asJsonObject
        Text(portablePeriodLabel(receipt.getAsJsonObject("targetWindow")))
        Text(portableVerdict(receipt.getAsJsonObject("assessment").get("verdict").asString))
        receipt.getAsJsonObject("assessment").get("expectedGross").takeUnless { it.isJsonNull }?.asJsonObject?.let {
            Text("Expected in source scope: ${formatMoney(it.get("amount").asString, it.get("currency").asString)}")
        }
        OutlinedButton(onClick = { onOpen(receipt.get("id").asString) },
            modifier = Modifier.fillMaxWidth().testTag("portable.history.${receipt.get("id").asString}")) {
            Text("Open source paycheck receipt")
        }
    }
}

@Composable
fun PortableReceiptDetail(archive: AndroidPortableArchive, receipt: JsonObject) {
    val assessment = receipt.getAsJsonObject("assessment")
    val period = archive.document.getAsJsonArray("periods").singleOrNull { it.asJsonObject.get("id") == receipt.get("periodRef") }?.asJsonObject
    val work = archive.document.getAsJsonArray("workSnapshots").single { it.asJsonObject.get("id") == receipt.get("workSnapshotRef") }.asJsonObject
    var showEvidence by rememberSaveable(receipt.get("id").asString) { mutableStateOf(false) }
    PageContent {
        Text("Source paycheck receipt", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.testTag("portable.receipt.title"))
        Text(portablePeriodLabel(receipt.getAsJsonObject("targetWindow")))
        SectionHeading(portableVerdict(assessment.get("verdict").asString))
        val expected = assessment.get("expectedGross").takeUnless { it.isJsonNull }?.asJsonObject
        if (expected == null) Text("Expected gross was not available in the source result.") else {
            MoneyText(formatMoney(expected.get("amount").asString, expected.get("currency").asString), large = true)
            Text("Expected within the original comparison scope")
        }
        val paid = assessment.getAsJsonObject("paidGross")
        Text("Statement gross: ${formatMoney(paid.get("amount").asString, paid.get("currency").asString)}")
        assessment.get("difference").takeUnless { it.isJsonNull }?.asJsonObject?.let {
            Text("Expected minus statement: ${formatMoney(it.get("amount").asString, it.get("currency").asString)}")
        }
        Text(if (assessment.get("scope").asString == "grossOnly") "Scope: gross-pay comparison only" else "Scope: source-confirmed paycheck lines")
        SectionHeading("Unresolved review")
        val reasons = assessment.getAsJsonArray("reviewReasons")
        if (reasons.isEmpty) Text("No review reason was recorded by the source. This is not independent verification of pay or legal coverage.")
        reasons.forEach { Text(portableReason(it.asString)) }
        Text("This saved source result is read-only. Android has not recalculated it, verified the source's rule applicability, or cleared any weekly-rate or legal review question.")
        TextButton(onClick = { showEvidence = !showEvidence }, modifier = Modifier.testTag("portable.receipt.show-evidence")) {
            Text(if (showEvidence) "Hide original source evidence" else "Show original source evidence")
        }
        if (showEvidence) {
            SectionHeading("Original identity and calculation version")
            Text("Receipt reference: ${receipt.get("id").asString}")
            PortableEvidence(receipt.get("producer"))
            PortableEvidence(receipt.get("targetWindow"), "Recorded work period")
            PortableEvidence(receipt.get("sourcePeriod"), "Recorded statement period")
            PortableEvidence(receipt.get("paystubFacts"), "Confirmed paycheck facts")
            PortableEvidence(receipt.get("lineFacts"), "Source line details")
            PortableEvidence(receipt.get("reviewFacts"), "Source confirmation details")
            PortableEvidence(assessment, "Frozen source assessment")
            PortableEvidence(receipt.get("calculation"), "Frozen source calculation")
            val ruleRefs = receipt.getAsJsonArray("ruleRefs").map { it.asString }.toSet()
            archive.document.getAsJsonArray("ruleSnapshots").filter { it.asJsonObject.get("id").asString in ruleRefs }
                .forEach { PortableEvidence(it, "Source rule snapshot") }
            PortableEvidence(work, "Original work snapshot")
            period?.let { PortableEvidence(it, "Retained period history") }
            Text("These references preserve the source evidence. Password encryption does not authenticate its author or establish legal applicability. A new native comparison is saved separately.")
        }
    }
}

private fun portablePeriodLabel(window: JsonObject): String {
    val start = window.get("startDate").takeUnless { it.isJsonNull }?.asString
    val last = window.get("endDateInclusive").takeUnless { it.isJsonNull }?.asString
    val zone = window.get("timeZone").takeUnless { it.isJsonNull }?.asString
    return if (start == null || last == null) "Period not recorded by source" else "$start – $last${zone?.let { " · $it" }.orEmpty()}"
}

private fun portableVerdict(value: String): String = when (value) {
    "matches" -> "Compared values match"
    "possibleShortfall", "possibleOverpayment" -> "Possible difference in source comparison"
    "needsReview" -> "Needs review"
    else -> "Not comparable"
}

private fun portableReason(value: String): String = when (value.replace("_", "").lowercase()) {
    "weeklyreviewpending" -> "Weekly-rate review is pending."
    "incompletework" -> "The source work log may be incomplete."
    "unsupportedrules" -> "Rule coverage is not confirmed."
    "unconfirmedgrossbasis" -> "The gross-pay basis is unconfirmed."
    "unconfirmedperiod" -> "The statement period is unconfirmed."
    "differentperiod" -> "The statement period differs from the work period."
    else -> value
}

/** Full source evidence is available on demand, after the worker-facing result and review scope. */
@Composable
private fun PortableEvidence(value: JsonElement, label: String? = null) {
    when {
        value.isJsonNull -> Text("${label ?: "Value"}: not recorded")
        value.isJsonPrimitive -> Text("${label ?: "Value"}: ${value.asString}")
        value.isJsonArray -> {
            label?.let { SectionHeading(it) }
            if (value.asJsonArray.isEmpty) Text("None recorded")
            value.asJsonArray.forEachIndexed { index, entry -> PortableEvidence(entry, if (entry.isJsonPrimitive) null else "Entry ${index + 1}") }
        }
        value.isJsonObject -> {
            label?.let { SectionHeading(it) }
            val unrecorded = value.asJsonObject.get("fieldsNotRecorded")?.takeIf { it.isJsonArray }?.asJsonArray?.map { it.asString }?.toSet().orEmpty()
            value.asJsonObject.entrySet().filter { it.key != "fieldsNotRecorded" }.forEach { (key, entry) ->
                val title = key.replace(Regex("([a-z])([A-Z])"), "$1 $2").replaceFirstChar { it.uppercase() }
                if (key in unrecorded) Text("$title: not recorded by source") else PortableEvidence(entry, title)
            }
        }
    }
}

@Composable
fun PortableAdoptionRequiredScreen(importedPeriodLabel: String? = null, onReview: () -> Unit) {
    PageContent {
        Text("Confirm rules for new estimates", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.testTag("portable.adoption-required"))
        importedPeriodLabel?.let { Text("Recorded current work period: $it", modifier = Modifier.testTag("portable.original-current-period")) }
        Text("Your imported work and original source receipts are retained. The source settings or saved work context cannot yet be used for new native estimates. Review them before calculating, adding work or comparing another paycheck. History stays readable, and exporting again preserves the original unknown fields and review reasons.")
        OutlinedButton(onClick = onReview, modifier = Modifier.fillMaxWidth().testTag("portable.review-adoption")) { Text("Review imported pay rules") }
    }
}

@Composable
fun PortableUnprojectedSourceScreen(state: AndroidLocalState, onReview: () -> Unit) {
    val profile = AndroidPortableStateCodec.sourceProfileForReview(state) ?: return
    val rule = state.portableArchive!!.document.getAsJsonArray("ruleSnapshots").single { it.asJsonObject.get("id") == profile.get("ruleRef") }.asJsonObject
    var evidence by rememberSaveable { mutableStateOf(false) }
    PageContent {
        Text("Imported pay rules need review", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.testTag("portable.unprojected-source"))
        Text("The source settings are incomplete or exceed Android's supported calculation inputs. The exact original values and receipts are retained read-only; no new estimate has been calculated.")
        Text("Recorded hourly rate: ${rule.get("hourlyRate").asString} ${rule.get("currency").asString}")
        portableCurrentPeriodLabel(state)?.let { Text("Recorded period context: $it") }
        Text("Confirm separate native rules and a new work context to continue. This does not fill in unknown source facts or clear its unresolved weekly or legal review reasons.")
        OutlinedButton(onClick = onReview, modifier = Modifier.testTag("portable.review-adoption")) { Text("Review imported pay rules") }
        TextButton(onClick = { evidence = !evidence }) { Text(if (evidence) "Hide original source evidence" else "Show original source evidence") }
        if (evidence) { PortableEvidence(profile, "Original pay profile"); PortableEvidence(rule, "Original rules") }
    }
}

fun portableCurrentPeriodLabel(state: AndroidLocalState): String? {
    val root = state.portableArchive?.document ?: return null
    val profile = AndroidPortableStateCodec.sourceProfileForReview(state) ?: return null
    val knownCurrent = root.getAsJsonArray("periods").map { it.asJsonObject }.filter { it.get("isCurrent").takeUnless { value -> value.isJsonNull }?.asBoolean == true }
    val periodRef = profile.get("currentPeriodRef").takeUnless { it.isJsonNull }?.asString
    val legacyContext = root.getAsJsonArray("periods").singleOrNull { it.asJsonObject.get("id").asString == periodRef }?.asJsonObject
        ?.takeIf { it.get("isCurrent").isJsonNull && it.get("closed").takeUnless { value -> value.isJsonNull }?.asBoolean != true }
    val period = knownCurrent.singleOrNull() ?: legacyContext ?: return null
    return portablePeriodLabel(period.getAsJsonObject("calendarWindow"))
}

fun portableRuleReviewLabel(field: String): String = when (field) {
    "noCurrentWorkspace" -> "the saved context is closed or is not the current work period"
    "unsupportedCurrentWork" -> "non-regular source work stays read-only; start a separate empty native ledger"
    "periodWindow" -> "the current work period differs from profile settings"
    "currentWorkProfileSelection" -> "current work belongs to a different saved pay profile"
    "periodRuleSelection" -> "which recorded rules to use for new estimates"
    "rounding" -> "rounding policy"
    "effectiveStartDate" -> "rule start date"
    "effectiveEndDateInclusive" -> "rule end date"
    "weeklyOvertime" -> "weekly statutory treatment remains unverified"
    else -> field.replace(Regex("([a-z])([A-Z])"), "$1 $2").lowercase()
}

fun portableFutureDefaultLabel(state: AndroidLocalState): String? {
    if (state.profile?.useAsFutureDefault == true) return "Current confirmed native rules"
    val root = state.portableArchive?.document ?: return null
    val ref = root.get("activeProfileRef").takeUnless { it.isJsonNull }?.asString ?: return "No saved future default"
    val profile = root.getAsJsonArray("profiles").single { it.asJsonObject.get("id").asString == ref }.asJsonObject
    val rule = root.getAsJsonArray("ruleSnapshots").single { it.asJsonObject.get("id") == profile.get("ruleRef") }.asJsonObject
    val name = profile.get("name").takeUnless { it.isJsonNull }?.asString?.let { "$it · " }.orEmpty()
    return name + rule.get("currency").asString + " " + rule.get("hourlyRate").asString + "/hour"
}
