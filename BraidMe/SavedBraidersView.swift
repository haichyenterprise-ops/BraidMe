import SwiftUI

struct SavedBraidersView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Braider?
    @State private var appeared = false

    private var savedBraiders: [Braider] {
        fb.braiders.filter { fb.savedBraiderIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if savedBraiders.isEmpty {
                    BMEmptyState(
                        icon: "heart",
                        title: "No saved braiders",
                        message: "Tap the heart on any braider's profile to save them here."
                    )
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: Space.sm) {
                            ForEach(Array(savedBraiders.enumerated()), id: \.element.id) { index, braider in
                                BigBraiderRow(braider: braider) {
                                    Haptic.select()
                                    selected = braider
                                }
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
                            }
                        }
                        .padding(Space.lg)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInk)
                }
            }
            .navigationDestination(item: $selected) { braider in
                BraiderProfileView(braider: braider)
            }
            .onAppear { appeared = true }
        }
    }
}