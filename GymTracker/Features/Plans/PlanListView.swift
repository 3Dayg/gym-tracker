import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Query(
        filter: #Predicate<WorkoutPlan> { $0.isDraft == false },
        sort: \WorkoutPlan.createdAt,
        order: .reverse
    )
    private var plans: [WorkoutPlan]

    @State private var path: [WorkoutPlan] = []
    @State private var planPendingDelete: WorkoutPlan?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(plans) { plan in
                    PlanListRow(plan: plan)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete") {
                                planPendingDelete = plan
                            }
                            .tint(.red)
                            .accessibilityIdentifier("deletePlan")
                        }
                }
            }
            .navigationTitle("Plans")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(
                    plan: plan,
                    onCancel: { cancelCreate(plan) },
                    onCreate: { finishCreate(plan) }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addPlan()
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                    .accessibilityIdentifier("newPlan")
                }
            }
            .overlay {
                if plans.isEmpty {
                    EmptyStateBlock(
                        title: "No Plans Yet",
                        systemImage: "list.bullet.rectangle",
                        description: "Create a workout plan to reuse it whenever you train.",
                        actionTitle: "Create Plan",
                        actionIdentifier: "emptyPlansCreatePlan",
                        action: { addPlan() }
                    )
                }
            }
            .onChange(of: navigation.planToEdit) { _, plan in
                revealIfNeeded(plan)
            }
            .onAppear {
                discardOrphanDrafts()
                revealIfNeeded(navigation.planToEdit)
            }
            .sheet(isPresented: Binding(
                get: { planPendingDelete != nil },
                set: { if !$0 { planPendingDelete = nil } }
            )) {
                ConfirmDestructiveSheet(
                    title: "Delete this plan?",
                    message: "\(planPendingDelete?.name ?? "Plan") will be removed. Workouts you already logged from it stay in History.",
                    keepTitle: "Keep Plan",
                    deleteTitle: "Delete Plan",
                    keepIdentifier: "keepPlan",
                    deleteIdentifier: "confirmDeletePlan",
                    onKeep: { planPendingDelete = nil },
                    onDelete: {
                        if let planPendingDelete {
                            modelContext.delete(planPendingDelete)
                            try? modelContext.save()
                        }
                        planPendingDelete = nil
                    }
                )
                .presentationDetents([.medium])
                .interactiveDismissDisabled()
            }
        }
    }

    private func revealIfNeeded(_ plan: WorkoutPlan?) {
        guard let plan, !plan.isDraft else { return }
        path = [plan]
        navigation.planToEdit = nil
    }

    private func addPlan() {
        let plan = WorkoutPlan(name: "New Plan", isDraft: true)
        modelContext.insert(plan)
        path = [plan]
    }

    private func finishCreate(_ plan: WorkoutPlan) {
        plan.isDraft = false
        try? modelContext.save()
    }

    private func cancelCreate(_ plan: WorkoutPlan) {
        path = []
        modelContext.delete(plan)
        try? modelContext.save()
    }

    private func discardOrphanDrafts() {
        let drafts = (try? modelContext.fetch(
            FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.isDraft })
        )) ?? []
        for draft in drafts where !path.contains(where: { $0.id == draft.id }) {
            modelContext.delete(draft)
        }
    }
}

private struct PlanListRow: View {
    let plan: WorkoutPlan

    private var summary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        NavigationLink(value: plan) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: summary.modalitySymbol)
                    .foregroundStyle(summary.canStart ? Color.primary : GymTheme.red)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                    Text(summary.listCaption())
                        .font(.caption)
                        .foregroundStyle(summary.canStart ? Color.secondary : GymTheme.red)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("planRow-\(plan.name)")
    }
}

