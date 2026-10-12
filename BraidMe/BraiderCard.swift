import SwiftUI

// MARK: - Verified seal

struct VerifiedSeal: View {
    var size: CGFloat = 13
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.bmUI(size, weight: .bold))
            .foregroundStyle(LinearGradient.bmGiltGradient)
            .accessibilityLabel("Verified")
    }
}

// MARK: - Standard row (medium detent)

struct BraiderCard: View {
    let braider: Braider
    var isHighlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                BMAvatar(
                    url: braider.avatarUrl,
                    size: 62,
                    ringed: isHighlighted,
                    initials: bmInitials(braider.name)
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(braider.name)
                            .font(.bmUI(16, weight: .bold))
                            .foregroundStyle(Color.bmText)
                            .lineLimit(1)
                        if braider.verified { VerifiedSeal() }
                    }

                    BMRatingLine(rating: braider.rating, count: braider.reviewCount, size: 12)

                    HStack(spacing: 6) {
                        Text("from £\(braider.priceFrom)")
                            .font(.bmNum(13, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                        if !braider.city.isEmpty {
                            Circle()
                                .fill(Color.bmTextFaint)
                                .frame(width: 3, height: 3)
                            Text(braider.city)
                                .font(.bmUI(12, weight: .medium))
                                .foregroundStyle(Color.bmTextDim)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.bmUI(12, weight: .bold))
                    .foregroundStyle(isHighlighted ? Color.bmOnGilt : Color.bmTextDim)
                    .frame(width: 34, height: 34)
                    .background(
                        isHighlighted ? Color.bmGilt : Color.white.opacity(0.07),
                        in: Circle()
                    )
            }
            .padding(Space.sm)
            .background(
                isHighlighted ? Color.bmGilt.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Color.bmGilt.opacity(0.45) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.985, dim: 0.02))
        .animation(Motion.press, value: isHighlighted)
    }
}

// MARK: - Feature card (expanded detent, saved list)

struct BigBraiderRow: View {
    let braider: Braider
    var isSaved: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                cover
                details
            }
            .bmCard(radius: Radius.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(BMPressStyle(scale: 0.985, dim: 0.02))
    }

    private var coverUrl: String {
        if !braider.coverUrl.isEmpty { return braider.coverUrl }
        return braider.portfolio.first?.imageUrl ?? ""
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            if coverUrl.isEmpty {
                LinearGradient(
                    colors: [Color.bmRaised, Color.bmSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 190)
                .overlay(
                    BraidMark(length: 130, thickness: 44, strand: 9, animated: false, edge: Color.bmRaised)
                        .opacity(0.35)
                )
            } else {
                RemoteImage(url: coverUrl)
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: Color.black.opacity(0.78), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(braider.name)
                        .font(.bmDisplay(24, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    if braider.verified { VerifiedSeal(size: 15) }
                }
                if !braider.tagline.isEmpty {
                    Text(braider.tagline)
                        .font(.bmUI(13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(1)
                }
            }
            .padding(Space.md)
        }
        .frame(height: 190)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.bmUI(10, weight: .bold))
                    .foregroundStyle(Color.bmGilt)
                Text(String(format: "%.1f", braider.rating))
                    .font(.bmNum(12, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, Space.sm)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7))
            .padding(Space.sm)
        }
        .overlay(alignment: .topLeading) {
            if isSaved {
                Image(systemName: "heart.fill")
                    .font(.bmUI(12, weight: .bold))
                    .foregroundStyle(Color.bmBad)
                    .frame(width: 30, height: 30)
                    .bmGlassCircle()
                    .padding(Space.sm)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var details: some View {
        HStack(spacing: Space.sm) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: Space.md) {
                    BMPriceTag(price: braider.priceFrom)
                    if !braider.responseTime.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.bmUI(10, weight: .bold))
                                .foregroundStyle(Color.bmOrchid)
                            Text("Replies \(braider.responseTime)")
                                .font(.bmUI(12, weight: .medium))
                                .foregroundStyle(Color.bmTextDim)
                        }
                    }
                }
                if !braider.specialties.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(braider.specialties.prefix(3)), id: \.self) { s in
                            Text(s)
                                .font(.bmUI(11, weight: .semibold))
                                .foregroundStyle(Color.bmTextDim)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(Color.white.opacity(0.07), in: Capsule())
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.bmUI(13, weight: .bold))
                .foregroundStyle(Color.bmOnGilt)
                .frame(width: 40, height: 40)
                .background(LinearGradient.bmGiltGradient, in: Circle())
        }
        .padding(Space.md)
    }
}
