import SwiftUI

// MARK: - Standard Row

struct BraiderCard: View {
    let braider: Braider
    var isHighlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                ZStack {
                    BMAvatar(url: braider.avatarUrl, size: 64, initials: initials, ringed: braider.verified)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: Space.xs) {
                        Text(braider.name)
                            .font(.bmUI(16, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.bmUI(11))
                                .foregroundStyle(Color.appAccent)
                        }
                    }

                    BMRatingLine(rating: braider.rating, count: braider.reviewCount, size: 12)

                    HStack(spacing: Space.xs) {
                        Text("from")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.bmMono(13, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        if !braider.city.isEmpty {
                            Text("·").foregroundStyle(Color.appSmoke)
                            Text(braider.city)
                                .font(.bmUI(11))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.appBackground)
                        .frame(width: 32, height: 32)
                    Image(systemName: "chevron.right")
                        .font(.bmUI(11, weight: .bold))
                        .foregroundStyle(Color.appAsh)
                }
            }
            .padding(.vertical, Space.md)
            .padding(.horizontal, isHighlighted ? Space.sm : 0)
            .background(
                Group {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(Color.appAccentTint)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
        .animate(Motion.press, value: isHighlighted)
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}

// MARK: - Big Row (Expanded)

struct BigBraiderRow: View {
    let braider: Braider
    let onTap: () -> Void

    @State private var imageLoaded = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if !braider.coverUrl.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        RemoteImage(url: braider.coverUrl)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.3)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )

                        // Rating badge
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.bmUI(10))
                                .foregroundStyle(Color.appAccent)
                            Text(String(format: "%.1f", braider.rating))
                                .font(.bmMono(12, weight: .bold))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
                        .padding(Space.sm)
                    }
                    .clipShape(
                        .rect(
                            topLeadingRadius: Radius.card,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: Radius.card
                        )
                    )
                }

                HStack(spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: Space.xs) {
                            Text(braider.name)
                                .font(.bmDisplay(20, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.bmUI(13))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.bmUI(14))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }

                        HStack(spacing: Space.md) {
                            BMPriceTag(price: braider.priceFrom)
                            if !braider.responseTime.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.bmUI(10))
                                    Text(braider.responseTime)
                                        .font(.bmMono(11, weight: .medium))
                                }
                                .foregroundStyle(Color.appAsh)
                            }
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.up.right")
                            .font(.bmUI(14, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                }
                .padding(Space.md)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.appInk.opacity(0.06), radius: 16, y: 8)
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}