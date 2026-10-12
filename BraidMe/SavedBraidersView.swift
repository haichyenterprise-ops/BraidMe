import SwiftUI

// =============================================================================
// SavedBraidersView — User's saved braiders, upgraded
// Alert-tinted header, staggered card reveals, empty state with icon.
// =============================================================================

struct SavedBraidersView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Braider?
    @State private var appeared = false

    // Ambient motion
    @State private var orbOffset: CGSize = .zero

    private var savedBraiders: [Braider] {
        fb.braiders.filter { fb.savedBraiderIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Ambient orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appAlert.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 520)
                    .offset(x: orbOffset.width, y: orbOffset.height - 200)
                    .blur(radius: 40)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header

                    if savedBraiders.isEmpty {
                        emptyState
                    } else {
                        listView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptic.press()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .frame(width: 40, height: 40)
                            .background(Color.appSurface, in: Circle())
                            .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selected) { braider in
                BraiderProfileView(braider: braider)
            }
            .onAppear {
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    orbOffset = CGSize(width: 30, height: 20)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAlert)
                    .frame(width: 20, height: 2)
                Text("YOUR COLLECTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAlert)
            }

            Text("Saved")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            Text(verbatim: "\(savedBraiders.count) braider\(savedBraiders.count == 1 ? "" : "s")")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                // Pulsing rings
                Circle()
                    .stroke(Color.appAlert.opacity(0.15), lineWidth: 1)
                    .frame(width: 130, height: 130)
                    .scaleEffect(1.15)
                    .opacity(0.5)

                Circle()
                    .fill(Color.appAlert.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "heart")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.appAlert)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Space.xs) {
                Text("No saved braiders")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.appInk)

                Text("Tap the heart on any braider's profile to save them here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Space.xl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, Space.xxl)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - List

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
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.85)
                            .delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.lg)
        }
    }
}