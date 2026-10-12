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
                AuroraBackground(intensity: 0.45)

                VStack(spacing: 0) {
                    BMSheetBar(
                        title: "Saved",
                        subtitle: savedBraiders.isEmpty
                            ? "Braiders you love, all in one place"
                            : "\(savedBraiders.count) braider\(savedBraiders.count == 1 ? "" : "s") you love"
                    ) {
                        dismiss()
                    }

                    if savedBraiders.isEmpty {
                        Spacer()
                        BMEmptyState(
                            icon: "heart",
                            title: "Nothing saved yet",
                            message: "Tap the heart on any braider's profile and they'll show up here."
                        )
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: Space.md) {
                                ForEach(Array(savedBraiders.enumerated()), id: \.element.id) { index, braider in
                                    BigBraiderRow(braider: braider, isSaved: true) {
                                        Haptic.select()
                                        selected = braider
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task {
                                                await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                                            }
                                        } label: {
                                            Label("Remove from saved", systemImage: "heart.slash")
                                        }
                                    }
                                    .reveal(appeared, delay: Motion.stagger(index), offset: 26, blur: 0)
                                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, Space.lg)
                            .padding(.bottom, Space.xl)
                            .animation(Motion.sheet, value: savedBraiders.count)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selected) { braider in
                BraiderProfileView(braider: braider)
            }
            .onAppear { appeared = true }
        }
    }
}
