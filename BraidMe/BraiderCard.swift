import SwiftUI

// MARK: - Standard row (medium detent)

struct BraiderCard: View {
    let braider: Braider
    var isHighlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: braider.avatarUrl, size: 60, initials: initials)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Space.xxs) {
                        Text(braider.name)
                            .font(.bmUI(15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.bmUI(11))
                                .foregroundStyle(Color.appAccent)
                        }
                    }

                    BMRatingLine(rating: braider.rating, count: braider.reviewCount, size: 11)

                    HStack(spacing: Space.xxs) {
                        Text("from")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.bmMono(12, weight: .semibold))
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

                Image(systemName: "chevron.right")
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(Color.appSmoke)
            }
            .padding(.vertical, Space.sm)
            .padding(.horizontal, isHighlighted ? Space.sm : 0)
            .background(isHighlighted ? Color.appAccentTint : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
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

// MARK: - Big row (expanded detent)

struct BigBraiderRow: View {
    let braider: Braider
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if !braider.coverUrl.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        RemoteImage(url: braider.coverUrl)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.bmUI(10))
                                .foregroundStyle(Color.appAccent)
                            Text(String(format: "%.1f", braider.rating))
                                .font(.bmMono(11, weight: .bold))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.appSurface, in: Capsule())
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

                HStack(spacing: Space.sm) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: Space.xxs) {
                            Text(braider.name)
                                .font(.bmDisplay(18, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.bmUI(12))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.bmUI(13))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }

                        HStack(spacing: Space.sm) {
                            BMPriceTag(price: braider.priceFrom)
                            if !braider.responseTime.isEmpty {
                                HStack(spacing: 3) {
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

                    Image(systemName: "chevron.right")
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(Color.appSmoke)
                }
                .padding(Space.md)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}