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
                AppTheme.cloud.ignoresSafeArea()

                if savedBraiders.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(savedBraiders.enumerated()), id: \.element.id) { idx, braider in
                                savedRow(braider)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.7, dampingFraction: 0.85)
                                            .delay(Double(idx) * 0.05),
                                        value: appeared
                                    )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .navigationDestination(item: $selected) { braider in
                BraiderProfileView(braider: braider)
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    private func savedRow(_ braider: Braider) -> some View {
        Button {
            Haptics.soft()
            selected = braider
        } label: {
            HStack(spacing: 14) {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.accent, lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(braider.name)
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(braider.tagline)
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.slate)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        StarRow(rating: braider.rating, size: 10)
                        Text(String(format: "%.1f", braider.rating))
                            .font(AppTheme.sans(11, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text("from £\(braider.priceFrom)")
                            .font(AppTheme.sans(11, weight: .medium))
                            .foregroundColor(AppTheme.accentDeep)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.stone)
            }
            .padding(14)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                Image(systemName: "heart")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 8) {
                Text("No saved braiders")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text("Tap the heart on any braider's profile to save them here.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}