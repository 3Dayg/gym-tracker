import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]

    @State private var path: [WorkoutPlan] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(plans) { plan in
                    PlanListRow(plan: plan)
                }
                .onDelete(perform: deletePlans)
            }
            .navigationTitle("Plans")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(plan: plan)
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
                }
            }
            .overlay {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No Plans Yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a workout plan to reuse it whenever you train.")
                    )
                }
            }
            .onChange(of: navigation.planToEdit) { _, plan in
                revealIfNeeded(plan)
            }
            .onAppear {
                revealIfNeeded(navigation.planToEdit)
            }
        }
    }

    private func revealIfNeeded(_ plan: WorkoutPlan?) {
        guard let plan else { return }
        path = [plan]
        navigation.planToEdit = nil
    }

    private func addPlan() {
        let plan = WorkoutPlan(name: "New Plan")
        modelContext.insert(plan)
        path = [plan]
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}

private struct PlanListRow: View {
    let plan: WorkoutPlan

    private var summary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        NavigationLink(value: plan) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                Text(summary.listCaption())
                    .font(.caption)
                    .foregroundStyle(summary.canStart ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
        }
    }
}
