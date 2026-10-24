package com.streamentry.linepay.android

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import com.google.gson.Gson
import com.streamentry.linepay.domain.ContributionBasis

private val BenefitInputSaver = Saver<AndroidBenefitInput, String>(
    save = { Gson().toJson(it) },
    restore = { Gson().fromJson(it, AndroidBenefitInput::class.java) },
)

private fun emptyBenefitSegment(period: AndroidBenefitPeriod) = AndroidBenefitSegment(
    ruleVersion = "", period = period, effectivePeriod = period, basis = ContributionBasis.ELIGIBLE_HOUR,
    rate = "", quantity = "", source = AndroidBenefitSource("", "", ""), eligibilityConfirmed = false,
)

@Composable
fun BenefitReviewScreen(
    state: AndroidLocalState,
    revises: AndroidBenefitReceipt?,
    saveError: String?,
    onSave: (AndroidLocalState) -> Boolean,
    onOpenReceipt: (String) -> Unit,
    onDirtyChanged: (Boolean) -> Unit,
) {
    val profile = requireNotNull(state.profile)
    val startingPeriod = AndroidBenefitPeriod(profile.cycleStartDate, "", profile.payrollTimeZone)
    var input by rememberSaveable(revises?.id, stateSaver = BenefitInputSaver) {
        mutableStateOf(revises?.input?.let { prior -> prior.copy(
            completeEligibilityConfirmed = false,
            segments = prior.segments.map { it.copy(eligibilityConfirmed = false) },
            statement = prior.statement?.copy(confirmed = false),
        ) } ?: AndroidBenefitInput(
            "", "", profile.currencyCode, startingPeriod, listOf(emptyBenefitSegment(startingPeriod)), false, null,
        ))
    }
    var preview by remember { mutableStateOf<AndroidBenefitReceipt?>(null) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    fun changed(next: AndroidBenefitInput) {
        input = if (next.fundName != input.fundName || next.fundIdentifier != input.fundIdentifier || next.currencyCode != input.currencyCode || next.period != input.period) {
            next.copy(completeEligibilityConfirmed = false, segments = next.segments.map { it.copy(eligibilityConfirmed = false) })
        } else next
        preview = null
        error = null
        onDirtyChanged(true)
    }
    fun segmentChanged(index: Int, next: AndroidBenefitSegment) {
        val old = input.segments[index]
        val substantiveChange = old.copy(eligibilityConfirmed = next.eligibilityConfirmed) != next
        val confirmedNext = if (substantiveChange) next.copy(eligibilityConfirmed = false) else next
        changed(input.copy(segments = input.segments.mapIndexed { i, prior -> if (i == index) confirmedNext else prior }, completeEligibilityConfirmed = false))
    }

    PageContent {
        Text(if (revises == null) "Review employer contributions" else "New benefit receipt revision", style = MaterialTheme.typography.headlineSmall)
        Text(AndroidBenefitRepository.COVERAGE)
        if (revises != null) Text("Original receipt ${revises.id} stays unchanged. Saving appends a new receipt.")
        SectionHeading("One fund and exact period")
        LocalTextField(input.fundName, { changed(input.copy(fundName = it)) }, "Fund display name", "benefit.fund")
        LocalTextField(input.fundIdentifier, { changed(input.copy(fundIdentifier = it)) }, "Unique fund identifier / source reference", "benefit.fund-id")
        Text("Use a source-specific fund number or reference that distinguishes this fund from others with the same name. This is your scope identifier, not a verified registry ID. Statements must use exactly the same identifier, including case.")
        LocalTextField(input.currencyCode, { changed(input.copy(currencyCode = it)) }, "Currency (for example USD)", "benefit.currency")
        BenefitPeriodFields(input.period, "benefit.period") { changed(input.copy(period = it)) }
        Text("Dates are local calendar boundaries. End date is exclusive. Enter actual eligibility below; wages do not establish eligibility.")

        input.segments.forEachIndexed { index, segment ->
            SectionHeading("Eligible segment ${index + 1}")
            BenefitPeriodFields(segment.period, "benefit.segment.$index.period") { segmentChanged(index, segment.copy(period = it)) }
            ContributionBasis.entries.forEach { basis ->
                BenefitCheck(segment.basis == basis, benefitBasisLabel(basis), "benefit.segment.$index.basis.${basis.name}") {
                    segmentChanged(index, segment.copy(basis = basis))
                }
            }
            LocalTextField(segment.rate, { segmentChanged(index, segment.copy(rate = it)) },
                if (segment.basis == ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS) "Rate as percent (5 means 5%)" else "Contribution rate in ${input.currencyCode}",
                "benefit.segment.$index.rate", KeyboardType.Decimal)
            LocalTextField(segment.quantity, { segmentChanged(index, segment.copy(quantity = it)) }, when (segment.basis) {
                ContributionBasis.ELIGIBLE_HOUR -> "Eligible hours from source"
                ContributionBasis.ELIGIBLE_DAY -> "Eligible days from source"
                ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS -> "Eligible earnings in ${input.currencyCode}"
                ContributionBasis.FIXED_PERIOD -> "Period quantity (exactly 1)"
            }, "benefit.segment.$index.quantity", KeyboardType.Decimal)
            if (segment.basis == ContributionBasis.FIXED_PERIOD) Text("A fixed-period rule requires exactly one segment. Segment and effective dates must equal the entire review period.")
            LocalTextField(segment.ruleVersion, { segmentChanged(index, segment.copy(ruleVersion = it)) }, "Source rule version", "benefit.segment.$index.version")
            Text("Rule effective dates (must contain this segment)")
            BenefitPeriodFields(segment.effectivePeriod, "benefit.segment.$index.effective") { segmentChanged(index, segment.copy(effectivePeriod = it)) }
            LocalTextField(segment.source.title, { segmentChanged(index, segment.copy(source = segment.source.copy(title = it))) }, "Source document title", "benefit.segment.$index.title")
            LocalTextField(segment.source.reference, { segmentChanged(index, segment.copy(source = segment.source.copy(reference = it))) }, "Source reference / clause / page", "benefit.segment.$index.reference")
            LocalTextField(segment.source.eligibilityEvidence, { segmentChanged(index, segment.copy(source = segment.source.copy(eligibilityEvidence = it))) }, "Eligibility facts and source basis", "benefit.segment.$index.evidence")
            BenefitCheck(segment.eligibilityConfirmed, "I checked this segment's dates, eligible quantity and rule against the source identified above. This records my confirmation; it does not establish legal applicability.", "benefit.segment.$index.confirm") {
                segmentChanged(index, segment.copy(eligibilityConfirmed = it))
            }
            if (input.segments.size > 1) TextButton(onClick = {
                changed(input.copy(segments = input.segments.filterIndexed { i, _ -> i != index }, completeEligibilityConfirmed = false))
            }, modifier = Modifier.testTag("benefit.segment.$index.remove")) { Text("Remove segment ${index + 1}") }
        }
        OutlinedButton(onClick = {
            changed(input.copy(segments = input.segments + emptyBenefitSegment(input.period), completeEligibilityConfirmed = false))
        }, enabled = input.segments.size < AndroidBenefitRepository.MAXIMUM_SEGMENTS,
            modifier = Modifier.fillMaxWidth().testTag("benefit.add-segment")) { Text("Add eligible segment") }
        BenefitCheck(input.completeEligibilityConfirmed, "I included every eligible segment for this fund and period, checked gaps and overlaps, and recorded any ineligible time in my source evidence.", "benefit.complete") {
            changed(input.copy(completeEligibilityConfirmed = it))
        }

        SectionHeading("Optional employer statement")
        Text("Blank means missing. Enter 0 only when the statement explicitly confirms zero. Employee deductions are outside this comparison.")
        BenefitCheck(input.statement != null, "Enter statement details", "benefit.statement.enabled") { enabled ->
            changed(input.copy(statement = if (enabled) AndroidBenefitStatement(
                input.fundName, "", input.currencyCode, input.period, null, null, null, "", false,
            ) else null))
        }
        input.statement?.let { statement ->
            fun statementChanged(next: AndroidBenefitStatement) {
                val substantiveChange = statement.copy(confirmed = next.confirmed) != next
                changed(input.copy(statement = if (substantiveChange) next.copy(confirmed = false) else next))
            }
            LocalTextField(statement.fundName, { statementChanged(statement.copy(fundName = it)) }, "Statement fund display name", "benefit.statement.fund")
            LocalTextField(statement.fundIdentifier, { statementChanged(statement.copy(fundIdentifier = it)) }, "Statement fund identifier / source reference", "benefit.statement.fund-id")
            LocalTextField(statement.currencyCode, { statementChanged(statement.copy(currencyCode = it)) }, "Statement currency", "benefit.statement.currency")
            BenefitPeriodFields(statement.period, "benefit.statement.period") { statementChanged(statement.copy(period = it)) }
            LocalTextField(statement.employerContribution ?: "", { statementChanged(statement.copy(employerContribution = it.ifEmpty { null })) }, "Employer contribution amount (optional)", "benefit.statement.amount", KeyboardType.Decimal)
            LocalTextField(statement.quantity ?: "", { statementChanged(statement.copy(quantity = it.ifEmpty { null }, quantityBasis = if (it.isEmpty()) null else statement.quantityBasis ?: ContributionBasis.ELIGIBLE_HOUR)) }, "Statement eligible units (optional)", "benefit.statement.quantity", KeyboardType.Decimal)
            if (statement.quantity != null) ContributionBasis.entries.forEach { basis ->
                BenefitCheck(statement.quantityBasis == basis, "Statement: ${benefitBasisLabel(basis)}", "benefit.statement.basis.${basis.name}") {
                    statementChanged(statement.copy(quantityBasis = basis))
                }
            }
            LocalTextField(statement.sourceReference, { statementChanged(statement.copy(sourceReference = it)) }, "Statement source reference", "benefit.statement.reference")
            BenefitCheck(statement.confirmed, "I checked the statement's fund, currency, exact dates, units and employer amount against the identified source.", "benefit.statement.confirm") {
                statementChanged(statement.copy(confirmed = it))
            }
        }
        Text("Rounding: combined contribution total, 2 decimal places, half up. Every unrounded segment remains in the receipt.")
        error?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        Button(onClick = {
            runCatching { AndroidBenefitRepository.preview(input, revises?.id) }
                .onSuccess { preview = it; error = null }
                .onFailure { error = it.message ?: "Check contribution details and source confirmations." }
        }, modifier = Modifier.fillMaxWidth().testTag("benefit.preview")) { Text("Preview contribution review") }
        preview?.let { receipt ->
            BenefitResultSummary(receipt)
            Button(onClick = {
                runCatching { AndroidBenefitRepository.append(state, receipt) }
                    .onSuccess { next ->
                        if (onSave(next)) {
                            onDirtyChanged(false)
                            onOpenReceipt(receipt.id)
                        }
                    }.onFailure { error = it.message ?: "Benefit receipt could not be saved." }
            }, modifier = Modifier.fillMaxWidth().testTag("benefit.save")) { Text("Save separate benefit receipt") }
        }
    }
}

@Composable
private fun BenefitPeriodFields(period: AndroidBenefitPeriod, tag: String, changed: (AndroidBenefitPeriod) -> Unit) {
    LocalTextField(period.start, { changed(period.copy(start = it)) }, "Start (YYYY-MM-DD)", "$tag.start")
    LocalTextField(period.endExclusive, { changed(period.copy(endExclusive = it)) }, "End exclusive (YYYY-MM-DD)", "$tag.end")
    LocalTextField(period.timeZone, { changed(period.copy(timeZone = it)) }, "Payroll time zone", "$tag.zone")
}

@Composable
private fun BenefitCheck(checked: Boolean, label: String, tag: String, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Checkbox(checked, onChange, modifier = Modifier.testTag(tag))
        Text(label, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun BenefitResultSummary(receipt: AndroidBenefitReceipt) {
    SectionHeading(benefitStatusLabel(receipt.result.status, receipt.result.limitation))
    MoneyText(formatMoney(receipt.result.expected, receipt.input.currencyCode), Modifier.testTag("benefit.expected"))
    Text("Expected employer contribution in this scope")
    receipt.result.paid?.let { Text("Statement employer contribution: ${formatMoney(it, receipt.input.currencyCode)}") }
    receipt.result.difference?.let { Text("Expected minus statement: ${formatMoney(it, receipt.input.currencyCode)}") }
    receipt.result.eligibleQuantity?.let { Text("Eligible quantity: $it · ${receipt.result.basis?.let(::benefitBasisLabel)}") }
    receipt.result.quantityDifference?.let { Text("Eligible minus statement quantity: $it") }
    Text(benefitLimitationLabel(receipt.result.limitation))
}

@Composable
fun BenefitReceiptDetailScreen(
    receipt: AndroidBenefitReceipt,
    onRevise: () -> Unit,
    onDelete: () -> Unit,
) {
    var deleting by remember { mutableStateOf(false) }
    var showingReferences by remember { mutableStateOf(false) }
    if (deleting) AlertDialog(
        onDismissRequest = { deleting = false },
        title = { Text("Delete this benefit receipt and its revisions?") },
        text = { Text("This removes the selected receipt and every later revision derived from it. Other benefit receipts, wages, work and paycheck results remain. Export a backup first if you need a copy.") },
        confirmButton = { TextButton(onClick = onDelete, modifier = Modifier.testTag("benefit.delete.confirm")) { Text("Delete receipt family") } },
        dismissButton = { TextButton(onClick = { deleting = false }) { Text("Keep receipts") } },
    )
    PageContent {
        Text("Benefit receipt", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.testTag("benefit.receipt.title"))
        BenefitResultSummary(receipt)
        Text("${receipt.input.fundName} · fund scope ${receipt.input.fundIdentifier}")
        Text("${receipt.input.period.start} – ${receipt.input.period.endExclusive} (end exclusive) · ${receipt.input.period.timeZone}")
        Text("Saved ${java.time.Instant.ofEpochSecond(receipt.createdAtEpochSeconds)}")
        receipt.revisesReceiptId?.let { Text("Updated receipt; the earlier result is retained in History.") }
        receipt.input.segments.forEach { segment ->
            SectionHeading("${benefitBasisLabel(segment.basis)} · rule ${segment.ruleVersion}")
            Text("${segment.period.start} – ${segment.period.endExclusive} (end exclusive) · ${segment.period.timeZone}")
            Text("${segment.quantity} × ${segment.rate}${if (segment.basis == ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS) "%" else " ${receipt.input.currencyCode}"}")
            val component = receipt.result.components.single { it.segmentId == segment.id }
            Text("Unrounded contribution: ${component.unroundedContribution} ${receipt.input.currencyCode}")
            Text("Effective ${segment.effectivePeriod.start} – ${segment.effectivePeriod.endExclusive} (end exclusive) · ${segment.effectivePeriod.timeZone}")
            Text("Source: ${segment.source.title} · ${segment.source.reference}")
            Text("Eligibility evidence: ${segment.source.eligibilityEvidence}")
            Text(if (segment.eligibilityConfirmed) "You confirmed this segment's eligibility against its source." else "This segment's eligibility is not confirmed.")
        }
        SectionHeading("Statement evidence")
        val statement = receipt.input.statement
        if (statement == null) Text("No statement entered. Payment is not verified.") else {
            Text("${statement.fundName} · fund scope ${statement.fundIdentifier} · ${statement.currencyCode} · ${statement.period.start} – ${statement.period.endExclusive} (end exclusive) · ${statement.period.timeZone}")
            Text("Employer amount: ${statement.employerContribution ?: "Missing"}; units: ${statement.quantity ?: "Missing"} ${statement.quantityBasis?.let(::benefitBasisLabel) ?: ""}")
            Text("Source: ${statement.sourceReference}")
            Text(if (statement.confirmed) "You confirmed the statement values and scope." else "The statement values and scope are not confirmed.")
        }
        Text(if (receipt.input.completeEligibilityConfirmed) "You confirmed the complete eligible scope for this fund and period." else "The complete eligible scope is not confirmed.")
        Text("Combined total rounded to 2 decimal places, half up.")
        Text(AndroidBenefitRepository.COVERAGE)
        TextButton(onClick = { showingReferences = !showingReferences }, modifier = Modifier.testTag("benefit.references")) {
            Text(if (showingReferences) "Hide calculation references" else "Show calculation references")
        }
        if (showingReferences) {
            Text("These references identify the exact retained calculation and its source snapshots in your manual backup.")
            Text("Receipt: ${receipt.id} · engine: ${receipt.result.engine}")
            receipt.revisesReceiptId?.let { Text("Earlier receipt: $it") }
            receipt.input.segments.forEach { Text("Rule: ${it.ruleId} · segment: ${it.id}") }
        }
        OutlinedButton(onClick = onRevise, modifier = Modifier.fillMaxWidth().testTag("benefit.revise")) { Text("Create a new revision") }
        TextButton(onClick = { deleting = true }, modifier = Modifier.testTag("benefit.delete")) { Text("Delete receipt and derived revisions") }
    }
}

@Composable
fun BenefitHistoryRows(receipts: List<AndroidBenefitReceipt>, onOpenReceipt: (String) -> Unit) {
    SectionHeading("Benefit contribution receipts")
    Text("Separate employer contribution references; wage and paycheck results are unchanged.")
    if (receipts.isEmpty()) Text("No saved benefit receipts yet.")
    receipts.asReversed().forEach { receipt ->
        Text("${receipt.input.fundName} · fund scope ${receipt.input.fundIdentifier} · ${receipt.input.period.start} – ${receipt.input.period.endExclusive} (end exclusive)")
        Text("${benefitStatusLabel(receipt.result.status, receipt.result.limitation)} · ${formatMoney(receipt.result.expected, receipt.input.currencyCode)} expected")
        if (receipt.result.limitation == "UNITS_ONLY") Text("Only units were compared; payment is not verified.")
        if (receipt.revisesReceiptId != null) Text("Revision; original retained")
        OutlinedButton(onClick = { onOpenReceipt(receipt.id) }, modifier = Modifier.fillMaxWidth().testTag("benefit.history.${receipt.id}")) { Text("Open benefit receipt") }
    }
}
