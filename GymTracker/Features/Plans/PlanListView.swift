import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]

    @State private var newPlan: WorkoutPlan?

    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    NavigationLink(value: plan) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                            Text(exerciseSummary(for: plan))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
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
            .navigationDestination(item: $newPlan) { plan in
                PlanEditorView(plan: plan)
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
        }
    }

    private func exerciseSummary(for plan: WorkoutPlan) -> String {
        let names = plan.orderedExercises.map(\.exerciseName)
        return names.isEmpty ? "No exercises" : names.joined(separator: " · ")
    }

    private func addPlan() {
        let plan = WorkoutPlan(name: "New Plan")
        modelContext.insert(plan)
        newPlan = plan
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}
