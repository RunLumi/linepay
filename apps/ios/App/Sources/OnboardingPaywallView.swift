import SwiftUI

struct ProPaywallView: View {
    enum Context: Equatable {
        case contextual
        /// The one-time offer that ends onboarding. `expectedPay` is the worker's own first result.
        case onboarding(expectedPay: String?)
    }

    let store: SubscriptionStore
    var context: Context = .contextual
    /// The moment the offer is shown; the trial timeline's dates count from here.
    var referenceDate = Date()
    let onPurchaseCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedProductID = SubscriptionStore.yearlyProductID
    @State private var isPurchasing = false
    @State private var purchaseConfirmed = false
    @State private var remindBeforeTrialEnds = true
    @State private var reminderDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.section) {
                    header
                    if case .onboarding(let expectedPay?) = context {
                        LabeledContent("Expected gross for the work you logged") {
                            Text(expectedPay).font(.title3.bold().monospacedDigit())
                        }
                        .labeledContentStyle(LinePayValueStyle())
                        .accessibilityIdentifier("paywall.your-result")
                    }
                    benefits
                    VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                        planRow(SubscriptionStore.yearlyProductID)
                        planRow(SubscriptionStore.monthlyProductID)
                    }
                    // Below the plans, so choosing a plan never moves the rows being tapped.
                    if let trial = selectedTrial, let days = trial.days,
                        days > TrialReminder.leadDays, let plan = selectedPlan
                    {
                        trialTimeline(days: days, plan: plan)
                        if store.purchasingEnabled {
                            Toggle(isOn: $remindBeforeTrialEnds) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Remind me before I'm charged").font(.headline)
                                    Text(
                                        "A notification \(TrialReminder.leadDays) days before the trial ends. Asked once, kept on this iPhone."
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(LinePayColor.textSecondary)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .tint(LinePayColor.brandPrimary)
                            .accessibilityIdentifier("paywall.trial-reminder")
                        }
                    }
                    storeStatus
                    if typeSize.isAccessibilitySize { purchaseControls }
                    footer
                }
                .padding(LinePaySpacing.section)
            }
            // Identify only the scrolling content: an identifier applied outside the inset would
            // replace the purchase controls' own identifiers.
            .accessibilityIdentifier("paywall.screen")
            .linePayHardTopEdge()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Keep the purchase terms and the free escape route reachable without scrolling.
                // At accessibility sizes they flow inline instead of covering the content.
                if !typeSize.isAccessibilitySize {
                    purchaseControls
                        .padding(.horizontal, LinePaySpacing.section)
                        .padding(.vertical, LinePaySpacing.standard)
                        .background(LinePayColor.canvas)
                        .overlay(alignment: .top) { Divider() }
                }
            }
            .background(LinePayColor.canvas)
            .navigationTitle("LinePaycheck Pro").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }.accessibilityIdentifier("paywall.dismiss")
                }
            }
            .alert("LinePaycheck Pro active", isPresented: $purchaseConfirmed) {
                Button("Continue") {
                    onPurchaseCompleted()
                    dismiss()
                }
            } message: {
                Text(confirmationText)
            }
        }
        .tint(LinePayColor.actionText)
        .task { await store.load() }
        .onChange(of: store.plans) { _, plans in
            // Never leave a selection pointing at a plan Apple did not supply.
            if !plans.contains(where: { $0.id == selectedProductID }), let first = plans.first {
                selectedProductID = first.id
            }
        }
    }

    // MARK: Content

    private var header: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text("Check every paycheck.")
                .font(.largeTitle.bold())
                .foregroundStyle(LinePayColor.textPrimary)
            if let trial = annualTrial, !store.isPro {
                // Constant across plan selection: it stays true when Monthly is chosen and never
                // shifts the plan rows. "Nothing is charged today" lives in the annual timeline.
                Text("Try Pro free for \(trial.duration) with the annual plan.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LinePayColor.actionText)
                    .accessibilityIdentifier("paywall.trial-headline")
            }
            Text("Pro compares each paycheck with the work you logged and the rules you confirmed.")
                .font(.body)
                .foregroundStyle(LinePayColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            benefit(
                "doc.text.viewfinder", title: "Every payday, not just the first",
                detail:
                    "Your first check is free. Pro checks each paycheck after that: scan the paystub or type in its gross pay."
            )
            benefit(
                "list.bullet.rectangle", title: "Follow every possible difference",
                detail: "Trace it back to the hours, rule and calculation behind it.")
            benefit(
                "square.and.arrow.up", title: "Keep a record of every check",
                detail: "Save the evidence behind each check and share it when you choose.")
        }
    }

    private func benefit(_ icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LinePayColor.actionText)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(LinePayColor.textPrimary)
                Text(detail).font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// States exactly when billing happens, on real calendar dates. The reminder step is promised
    /// only while the reminder switch is on, and the app schedules it after the trial starts.
    private func trialTimeline(days: Int, plan: ProPlan) -> some View {
        let ends = Self.timelineDate(daysFromNow: days, from: referenceDate)
        let remind = Self.timelineDate(
            daysFromNow: days - TrialReminder.leadDays, from: referenceDate)
        return VStack(alignment: .leading, spacing: 0) {
            Text("How the free trial works")
                .font(.headline)
                .padding(.bottom, LinePaySpacing.compact)
            timelineStep(
                "lock.open", when: "Today",
                detail: "Pro unlocks. Nothing is charged today.", isLast: false)
            timelineStep(
                remindBeforeTrialEnds && store.purchasingEnabled ? "bell" : "calendar",
                when: remind,
                detail: remindBeforeTrialEnds && store.purchasingEnabled
                    ? "We remind you the trial ends in \(TrialReminder.leadDays) days. Cancel at least 24 hours before it ends in Apple subscription settings and you pay nothing."
                    : "Cancel at least 24 hours before the trial ends in Apple subscription settings and you pay nothing.",
                isLast: false)
            timelineStep(
                "creditcard", when: ends,
                detail: "Your annual plan starts: \(plan.displayPrice) for the \(plan.periodName).",
                isLast: true)
        }
        .padding(LinePaySpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinePayColor.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("paywall.trial-timeline")
    }

    /// "Oct 11": a date the worker can put in a calendar, not a day count to work out.
    static func timelineDate(daysFromNow days: Int, from start: Date) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func timelineStep(_ icon: String, when: String, detail: String, isLast: Bool)
        -> some View
    {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LinePayColor.actionOnFill)
                    .frame(width: 30, height: 30)
                    .background(LinePayColor.brandPrimary, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(LinePayColor.lineStrong)
                        .frame(width: 2)
                        .frame(minHeight: 16, maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(when).font(.subheadline.bold()).foregroundStyle(LinePayColor.textPrimary)
                Text(detail).font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, isLast ? 0 : LinePaySpacing.standard)
        }
        .accessibilityElement(children: .combine)
    }

    private func planRow(_ id: String) -> some View {
        let plan = store.plan(id: id)
        let yearly = id == SubscriptionStore.yearlyProductID
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? LinePayColor.actionText : LinePayColor.lineStrong)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.compact) {
                        Text(yearly ? "Annual · Recommended" : "Monthly").font(.headline)
                        Spacer(minLength: 0)
                        if yearly, let percent = store.annualSavingsPercent {
                            badge("Save \(percent)%")
                        }
                    }
                    Text(priceLine(plan)).font(.title3.bold().monospacedDigit())
                    if let plan { Text(planDetail(plan)).font(.subheadline) }
                }
                .foregroundStyle(LinePayColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LinePaySpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinePayColor.surfacePrimary)
            .overlay {
                RoundedRectangle(cornerRadius: 10).stroke(
                    selected ? LinePayColor.actionText : LinePayColor.lineStrong,
                    lineWidth: selected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(yearly ? "paywall.yearly" : "paywall.monthly")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func priceLine(_ plan: ProPlan?) -> String {
        plan.map { "\($0.displayPrice) / \($0.periodName)" } ?? "Price unavailable"
    }

    private func planDetail(_ plan: ProPlan) -> String {
        switch (plan.period, plan.freeTrial) {
        case (.year, let trial?):
            let equivalent = plan.monthlyEquivalent.map { " Works out to \($0)/month." } ?? ""
            return "\(trial.duration) free, then billed yearly.\(equivalent)"
        case (.year, nil):
            let equivalent = plan.monthlyEquivalent.map { " Works out to \($0)/month." } ?? ""
            return "Billed yearly, starting today.\(equivalent)"
        case (.month, _):
            return "Billed monthly, starting today. No free trial."
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(LinePayColor.actionOnFill)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(LinePayColor.brandPrimary, in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()
    }

    @ViewBuilder private var storeStatus: some View {
        if store.isLoading { ProgressView("Checking App Store prices and offers…") }
        if let message = store.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(LinePayColor.review)
        }
        if store.plans.isEmpty, !store.isLoading, store.purchasingEnabled {
            Button("Retry App Store prices") { Task { await store.load() } }
                .frame(minHeight: 48)
                .accessibilityIdentifier("paywall.retry")
        }
    }

    private var purchaseControls: some View {
        VStack(spacing: LinePaySpacing.compact) {
            if store.isPro {
                Button("Continue to my work") { dismiss() }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .accessibilityIdentifier("paywall.continue-pro")
            } else {
                Button(purchaseTitle) { purchase() }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .disabled(!canPurchase || isPurchasing)
                    .accessibilityIdentifier("paywall.purchase")
                Text(billingTerms)
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.terms")
                Button("Continue free") { dismiss() }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("paywall.continue-free")
                    .accessibilityHint("Keeps your saved work and the free features")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text(
                "No LinePaycheck account. Your pay data stays on this iPhone by default, and saved records stay readable if Pro ends."
            )
            .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            Button("Restore Purchases") {
                Task {
                    await store.restorePurchases()
                    if store.isPro { purchaseConfirmed = true }
                }
            }
            .disabled(!store.purchasingEnabled)
            .frame(minHeight: 44).accessibilityIdentifier("paywall.restore")
            Link("Manage subscription", destination: AppLinks.subscriptions).frame(minHeight: 44)
            NavigationLink("Privacy policy") { LegalTextView(kind: .privacy) }.frame(minHeight: 44)
            NavigationLink("Terms of use") { LegalTextView(kind: .terms) }.frame(minHeight: 44)
        }
    }

    // MARK: Purchase state

    private var selectedPlan: ProPlan? { store.plan(id: selectedProductID) }
    private var annualTrial: ProPlan.FreeTrial? {
        store.plan(id: SubscriptionStore.yearlyProductID)?.freeTrial
    }
    private var selectedTrial: ProPlan.FreeTrial? { selectedPlan?.freeTrial }
    /// Plans exist only for products Apple supplied, so a missing plan can never be purchased.
    private var canPurchase: Bool {
        store.purchasingEnabled && !store.isLoading && selectedPlan != nil
    }
    private var purchaseTitle: String {
        if isPurchasing { return "Purchasing…" }
        guard canPurchase else { return store.isLoading ? "Loading prices…" : "Prices unavailable" }
        if let trial = selectedTrial { return "Start my \(trial.length) free trial" }
        return selectedPlan?.period == .year ? "Subscribe yearly" : "Subscribe monthly"
    }
    private var billingTerms: String {
        guard let plan = selectedPlan else {
            return
                "Pro can be bought once the App Store supplies its price. Your saved work and free features remain available."
        }
        if let trial = plan.freeTrial {
            return
                "\(trial.duration) free, then \(plan.displayPrice) per \(plan.periodName), renewing automatically. Cancel at least 24 hours before the trial ends to avoid being charged."
        }
        return
            "\(plan.displayPrice) billed today and every \(plan.periodName) until you cancel in Apple subscription settings."
    }
    private var confirmationText: String {
        guard let date = store.renewalDate else {
            return
                "Apple verified your Pro access. Your saved work is ready to continue. Manage billing in Apple subscription settings."
        }
        let action = store.willAutoRenew == true ? "Renews" : "Ends"
        let prefix = store.isTrial ? "Your free trial is active. " : "Your subscription is active. "
        var reminder = ""
        if store.isTrial, remindBeforeTrialEnds {
            reminder =
                reminderDate.map {
                    " We'll remind you on \($0.formatted(date: .abbreviated, time: .omitted))."
                }
                ?? " No reminder was set: notifications for LinePaycheck are off or unavailable."
        }
        return prefix
            + "\(action) on \(date.formatted(date: .abbreviated, time: .shortened)).\(reminder) Manage billing in Apple subscription settings."
    }
    private func purchase() {
        guard canPurchase else { return }
        isPurchasing = true
        let renewalPrice = selectedPlan.map { "\($0.displayPrice) per \($0.periodName)" } ?? ""
        Task {
            let purchased = await store.purchase(productID: selectedProductID)
            if purchased, store.isTrial, remindBeforeTrialEnds, let ends = store.renewalDate {
                reminderDate = await TrialReminder.schedule(
                    trialEnds: ends, renewalPrice: renewalPrice)
            }
            purchaseConfirmed = purchased
            isPurchasing = false
        }
    }
}
