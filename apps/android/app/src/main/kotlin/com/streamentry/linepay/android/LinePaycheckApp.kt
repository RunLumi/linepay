package com.streamentry.linepay.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.foundation.isSystemInDarkTheme

private val LightColors = lightColorScheme(
    primary = Color(0xFF0B6D66),
    onPrimary = Color.White,
    background = Color(0xFFF4F1E8),
    onBackground = Color(0xFF13171A),
    surface = Color(0xFFFBFAF6),
    onSurface = Color(0xFF13171A),
    surfaceVariant = Color(0xFFE9E5DB),
    onSurfaceVariant = Color(0xFF5C6468),
    error = Color(0xFFB13C35),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF55C9BE),
    onPrimary = Color(0xFF111417),
    background = Color(0xFF111417),
    onBackground = Color(0xFFF4F1E8),
    surface = Color(0xFF1A1F23),
    onSurface = Color(0xFFF4F1E8),
    surfaceVariant = Color(0xFF22282C),
    onSurfaceVariant = Color(0xFFAAB2B6),
    error = Color(0xFFFFB4AB),
)

@Composable
fun LinePaycheckTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}

private enum class MainTab(val title: String, val tag: String) {
    TODAY("Today", "nav.today"),
    PAY("Pay", "nav.pay"),
    HISTORY("History", "nav.history"),
    SETTINGS("Settings", "nav.settings"),
}

private enum class AppPage(val title: String) {
    ROOT(""),
    SETUP("Pay rules"),
    ADD_WORK("Add work"),
    RECORD_PAYCHECK("Record paycheck"),
    WEEKLY_REVIEW("Weekly rate review"),
    WEEKLY_RECEIPT("Weekly review receipt"),
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun LinePaycheckApp(
    state: AndroidLocalState,
    activity: AndroidLocalActivitySnapshot,
    loadError: String?,
    saveError: String?,
    activityError: String?,
    onSaveState: (AndroidLocalState) -> Boolean,
    onSaveActivity: (AndroidLocalActivitySnapshot) -> Boolean,
) {
    var selectedTab by rememberSaveable { mutableStateOf(MainTab.TODAY) }
    var page by rememberSaveable { mutableStateOf(AppPage.ROOT) }
    var editingProfile by rememberSaveable { mutableStateOf(false) }
    var selectedWeeklyReceiptId by rememberSaveable { mutableStateOf<String?>(null) }
    val activeProfile = state.profile

    if (loadError != null) {
        LinePaycheckTheme {
            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                Column(Modifier.padding(24.dp)) {
                    Text("Saved data needs review", style = MaterialTheme.typography.headlineSmall)
                    Text(loadError, Modifier.padding(top = 16.dp))
                    Text(
                        "Existing records were left in place. Use a known-good manual backup or contact support before changing files.",
                        Modifier.padding(top = 12.dp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        return
    }

    Scaffold(
        modifier = Modifier.semantics { testTagsAsResourceId = true },
        topBar = {
            if (activeProfile != null && page != AppPage.ROOT) {
                TopAppBar(
                    title = { Text(if (page == AppPage.SETUP && !editingProfile) "Pay rules" else page.title) },
                    navigationIcon = {
                        androidx.compose.material3.TextButton(
                            onClick = {
                                page = AppPage.ROOT
                                editingProfile = false
                            },
                            modifier = Modifier.testTag("navigation.back"),
                        ) { Text("Back") }
                    },
                )
            } else if (activeProfile != null) {
                TopAppBar(title = { Text(selectedTab.title) })
            }
        },
        bottomBar = {
            if (activeProfile != null && page == AppPage.ROOT) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                    MainTab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = selectedTab == tab,
                            onClick = { selectedTab = tab },
                            icon = { Text(tab.title.take(1), fontWeight = FontWeight.Bold) },
                            label = { Text(tab.title) },
                            modifier = Modifier.testTag(tab.tag),
                        )
                    }
                }
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { insets ->
        Surface(
            modifier = Modifier.fillMaxSize().padding(insets),
            color = MaterialTheme.colorScheme.background,
        ) {
            when {
                activeProfile == null -> PayRuleSetupScreen(
                    initial = null,
                    saveError = saveError,
                    onSave = { profile ->
                        if (onSaveState(state.copy(profile = profile))) {
                            selectedTab = MainTab.TODAY
                            page = AppPage.ROOT
                        }
                    },
                )
                page == AppPage.ADD_WORK -> AddWorkScreen(
                    state = state,
                    saveError = saveError,
                    onSave = { next ->
                        if (onSaveState(next)) page = AppPage.ROOT
                    },
                )
                page == AppPage.RECORD_PAYCHECK -> RecordPaycheckScreen(
                    state = state,
                    saveError = saveError,
                    onSave = { next ->
                        if (onSaveState(next)) {
                            selectedTab = MainTab.PAY
                            page = AppPage.ROOT
                        }
                    },
                )
                page == AppPage.WEEKLY_REVIEW -> WeeklyRateReviewScreen(
                    state = state,
                    saveError = saveError,
                    onSave = onSaveState,
                    onOpenHistory = {
                        selectedTab = MainTab.HISTORY
                        page = AppPage.ROOT
                    },
                    onOpenWeeklyReceipt = { id ->
                        selectedWeeklyReceiptId = id
                        page = AppPage.WEEKLY_RECEIPT
                    },
                )
                page == AppPage.WEEKLY_RECEIPT -> {
                    val receipt = state.weeklyReviews.singleOrNull { it.id == selectedWeeklyReceiptId }
                    if (receipt == null) {
                        PageContent {
                            Text("This weekly review receipt is no longer available.")
                        }
                    } else {
                        WeeklyReviewReceiptDetailScreen(receipt)
                    }
                }
                page == AppPage.SETUP -> PayRuleSetupScreen(
                    initial = if (editingProfile) activeProfile else null,
                    saveError = saveError,
                    onSave = { profile ->
                        if (onSaveState(state.copy(profile = profile))) {
                            editingProfile = false
                            page = AppPage.ROOT
                        }
                    },
                )
                else -> when (selectedTab) {
                    MainTab.TODAY -> TodayScreen(
                        state = state,
                        saveError = saveError,
                        onAddWork = { page = AppPage.ADD_WORK },
                        onOpenPay = { selectedTab = MainTab.PAY },
                    )
                    MainTab.PAY -> PayScreen(
                        state = state,
                        onRecordPaycheck = { page = AppPage.RECORD_PAYCHECK },
                        onOpenHistory = { selectedTab = MainTab.HISTORY },
                        onWeeklyReview = { page = AppPage.WEEKLY_REVIEW },
                        onOpenWeeklyReceipt = { id ->
                            selectedWeeklyReceiptId = id
                            page = AppPage.WEEKLY_RECEIPT
                        },
                    )
                    MainTab.HISTORY -> HistoryScreen(
                        state = state,
                        saveError = saveError,
                        onDeleteCheck = { id ->
                            runCatching { AndroidWeeklyReviewRepository.deletePaycheckPeriod(state, id) }
                                .fold(onSuccess = onSaveState, onFailure = { false })
                        },
                        onOpenWeeklyReceipt = { id ->
                            selectedWeeklyReceiptId = id
                            page = AppPage.WEEKLY_RECEIPT
                        },
                    )
                    MainTab.SETTINGS -> SettingsScreen(
                        state = state,
                        activity = activity,
                        activityError = activityError,
                        saveError = saveError,
                        onEditRules = {
                            editingProfile = true
                            page = AppPage.SETUP
                        },
                        onSaveState = onSaveState,
                        onSaveActivity = onSaveActivity,
                    )
                }
            }
        }
    }
}

@Composable
fun PageContent(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(20.dp),
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding),
        content = content,
    )
}

@Composable
fun SectionHeading(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier.padding(top = 18.dp, bottom = 8.dp),
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
fun MoneyText(value: String, modifier: Modifier = Modifier, large: Boolean = false) {
    Text(
        text = value,
        modifier = modifier,
        style = if (large) MaterialTheme.typography.headlineLarge else MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.Bold,
        textAlign = TextAlign.Start,
        letterSpacing = 0.sp,
    )
}

@Composable
fun InlineMessage(text: String, isError: Boolean = false, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier.padding(vertical = 8.dp),
        color = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
        style = MaterialTheme.typography.bodyMedium,
    )
}
