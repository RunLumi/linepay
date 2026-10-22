package com.streamentry.linepay.android

import com.google.gson.JsonObject

/** Local-only crosswalk. The portable document retains the original producer's identity metadata. */
data class AndroidPortableLocalIdentity(val entityType: String, val portableID: String, val localID: String)

/** Validated typed v1 portable records, retained verbatim as source evidence, never native JSON blobs. */
data class AndroidPortableArchive(
    val document: JsonObject,
    val localIdentities: List<AndroidPortableLocalIdentity>,
    val localAdoptions: List<AndroidPortableAdoption> = emptyList(),
)

/** A destination confirmation, distinct from every frozen source profile and rule. */
data class AndroidPortableAdoption(
    val sourceProfileRef: String,
    val sourcePeriodRef: String?,
    val sourceWorkSnapshotRef: String?,
    val sourceRuleRefs: List<String>,
    val makeDefaultForFuture: Boolean,
    val adoptedProfile: AndroidRuleProfile,
    val adoptedWork: List<AndroidWorkEntry>,
    val confirmedAtEpochSeconds: Long,
    val confirmedFields: List<String>,
)
