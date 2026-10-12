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

                RadialGradient(
                    colors: [Color.appAlert.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if savedBraiders.isEmpty {
                        BMEmptyState(
                            icon: "heart",
                            title: "No saved braiders",
                            message: "Tap the heart on any braider's profile to save them here."
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        listView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BMGlassIconButton(icon: "xmark", size: 40, iconSize: 14, tint: .appInk) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selected) { braider in
                BraiderProfileView(braider: braider)
            }
            .onAppear {
                withAnimation(Motion.heroReveal.delay(0.1)) { appeared = true }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAlert)
                    .frame(width: 20, height: 2)
                Text("YOUR COLLECTION")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAlert)
            }

            Text("Saved")
                .font(.bmHero(34))
                .foregroundStyle(Color.appInk)
                .lineSpacing(-4)

            Text(verbatim: "\(savedBraiders.count) braider\(savedBraiders.count == 1 ? "" : "s")")
                .font(.bmUI(14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animate(Motion.heroReveal, value: appeared)
    }

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Space.md) {
                ForEach(Array(savedBraiders.enumerated()), id: \.element.id) { index, braider in
                    BigBraiderRow(braider: braider) {
                        Haptic.select()
                        selected = braider
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
                }
                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.lg)
        }
    }
}