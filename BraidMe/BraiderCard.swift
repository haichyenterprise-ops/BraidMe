import SwiftUI

// =============================================================================
// SheetReviewRow — Reviews in sheets, upgraded
// Gradient ring avatar, staggered star materialization, gold left-rail.
// =============================================================================

struct SheetReviewRow: View {
    let review: Review

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            // Gold left rail
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gold.opacity(0.9), Color.gold.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: appeared)

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    avatarWithRing

                    VStack(alignment: .leading, spacing: 3) {
                        Text(review.userName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)

                        HStack(spacing: Space.xxs) {
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.gold)
                                        .opacity(appeared ? 1 : 0)
                                        .scaleEffect(appeared ? 1 : 0.5)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.6)
                                                .delay(0.1 + Double(i) * 0.04),
                                            value: appeared
                                        )
                                }
                            }
                            Text(review.dateString)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appAsh)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Text(review.text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appInk.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                if !review.styleDone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                            .font(.system(size: 9, weight: .semibold))
                        Text(review.styleDone)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.3)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.goldInk)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 4)
                    .background(Color.gold.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Color.gold.opacity(0.3), lineWidth: 0.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(.easeOut(duration: 0.45).delay(0.35), value: appeared)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    private var avatarWithRing: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.gold.opacity(0.9),
                            Color.goldLight.opacity(0.6),
                            Color.goldDeep.opacity(0.4),
                            Color.gold.opacity(0.9)
                        ],
                        center: .center,
                        angle: .degrees(0)
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 44, height: 44)

            if review.userAvatar.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.14))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(userInitials)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: review.userAvatar)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            }
        }
    }

    private var userInitials: String {
        let parts = review.userName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}