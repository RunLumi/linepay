package com.streamentry.linepay.android

import com.google.gson.JsonObject
import com.streamentry.linepay.domain.EarningsLayout
import com.streamentry.linepay.domain.GuaranteeLayout
import com.streamentry.linepay.domain.Money
import com.streamentry.linepay.domain.PaycheckHoursBasis
import com.streamentry.linepay.domain.PaycheckLineField
import java.math.BigDecimal

/** A recorded manual observation. Null is unentered, including when the amount would be zero. */
data class AndroidConfirmedPaycheckLines(
    val currencyCode: String,
    val version: Int = 1,
    val layout: String = EarningsLayout.UNCONFIRMED.name,
    val hoursBasis: String = PaycheckHoursBasis.UNCONFIRMED.name,
    val guaranteeLayout: String = GuaranteeLayout.UNCONFIRMED.name,
    val regularPay: String? = null,
    val overtimePay: String? = null,
    val doubleTimePay: String? = null,
    val calloutPay: String? = null,
    val regularHours: String? = null,
    val overtimeHours: String? = null,
    val doubleTimeHours: String? = null,
    val paidPerDiem: String? = null,
    val completeEarningsLines: Boolean = false,
) {
    fun amounts(): Map<PaycheckLineField, String> = linkedMapOf(
        PaycheckLineField.REGULAR_PAY to regularPay,
        PaycheckLineField.OVERTIME_PAY to overtimePay,
        PaycheckLineField.DOUBLE_TIME_PAY to doubleTimePay,
        PaycheckLineField.CALLOUT_PAY to calloutPay,
    ).mapNotNull { (key, value) -> value?.let { key to it } }.toMap()

    fun hours(): Map<PaycheckLineField, String> = linkedMapOf(
        PaycheckLineField.REGULAR_HOURS to regularHours,
        PaycheckLineField.OVERTIME_HOURS to overtimeHours,
        PaycheckLineField.DOUBLE_TIME_HOURS to doubleTimeHours,
    ).mapNotNull { (key, value) -> value?.let { key to it } }.toMap()

    fun validate() {
        require(Regex("[A-Z]{3}").matches(currencyCode)) { "Identify the three-letter statement currency." }
        require(version == 1) { "Unsupported paycheck source-input version." }
        require(layout in EarningsLayout.entries.map { it.name }) { "Unknown earnings layout." }
        require(hoursBasis in PaycheckHoursBasis.entries.map { it.name }) { "Unknown source hours basis." }
        require(guaranteeLayout in GuaranteeLayout.entries.map { it.name }) { "Unknown callout mapping." }
        amounts().values.forEach { observedDecimal(it, hours = false) }
        hours().values.forEach { observedDecimal(it, hours = true) }
        paidPerDiem?.let { observedDecimal(it, hours = false) }
    }

    fun domainAmounts(currency: String): Map<PaycheckLineField, Money> = amounts().mapValues { Money(observedDecimal(it.value, hours = false), currency) }
    fun domainHours(): Map<PaycheckLineField, BigDecimal> = hours().mapValues { observedDecimal(it.value, hours = true) }
}

internal fun observedDecimal(value: String, hours: Boolean): BigDecimal {
    require(Regex("(?:0|[1-9][0-9]{0,12})(?:\\.[0-9]{1,12})?").matches(value)) {
        "Enter a nonnegative decimal with at most twelve fractional places; blank means unknown."
    }
    return BigDecimal(value).also {
        require(it <= if (hours) BigDecimal("10000") else BigDecimal("1000000000000")) {
            if (hours) "Observed hours exceed 10,000." else "Observed money exceeds the supported amount."
        }
    }
}

/** Gson must not coerce numeric observations, absent confirmations or unknown enum strings. */
internal fun validateCapturedLineJson(root: JsonObject) {
    val optional = setOf("regularPay", "overtimePay", "doubleTimePay", "calloutPay", "regularHours", "overtimeHours", "doubleTimeHours", "paidPerDiem")
    val required = setOf("version", "currencyCode", "layout", "hoursBasis", "guaranteeLayout", "completeEarningsLines")
    val checks = root.get("checks")
    if (checks?.isJsonArray != true) throw InvalidLocalState("Saved paycheck checks are missing or invalid.")
    checks.asJsonArray.forEach { encoded ->
        if (!encoded.isJsonObject) throw InvalidLocalState("A saved paycheck check is invalid.")
        val capture = encoded.asJsonObject.get("confirmedLineFacts")?.takeUnless { it.isJsonNull } ?: return@forEach
        require(capture.isJsonObject) { "Recorded paycheck source inputs must be an object." }
        val fields = capture.asJsonObject
        require(fields.keySet().containsAll(required) && fields.keySet().all { it in required + optional }) { "Recorded paycheck source inputs have missing or unsupported fields." }
        require(fields.get("version").isJsonPrimitive && fields.get("version").asJsonPrimitive.isNumber && fields.get("version").asString == "1") { "Unsupported paycheck source-input version." }
        require(fields.get("completeEarningsLines").isJsonPrimitive && fields.get("completeEarningsLines").asJsonPrimitive.isBoolean) { "Confirm whether the entered earnings breakdown is complete." }
        for (key in optional + setOf("currencyCode", "layout", "hoursBasis", "guaranteeLayout")) {
            fields.get(key)?.takeUnless { it.isJsonNull }?.let { require(it.isJsonPrimitive && it.asJsonPrimitive.isString) { "Recorded source values must use decimal or enum strings." } }
        }
        for (key in setOf("currencyCode", "layout", "hoursBasis", "guaranteeLayout")) require(!fields.get(key).isJsonNull) { "A recorded source mapping must explicitly remain unconfirmed or choose a supported mapping." }
    }
}
