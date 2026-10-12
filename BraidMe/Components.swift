import SwiftUI

// =============================================================================
// Shared components — Dynamic Type aware, haptic-restrained.
// =============================================================================

// MARK: - Buttons

struct BMPrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var loading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            ZStack {
                HStack(spacing: Space.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.bmUI(15, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.bmUI(16, weight: .semibold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.bmUI(12, weight: .medium))
                                .opacity(0.65)
                        }
                    }
                }
                .opacity(loading ? 0 : 1)

                if loading {
                    ProgressView().tint(Color.appInkInverse)
                }
            }
            .foregroundStyle(Color.appInkInverse)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.vertical, Space.xs)
            .background(Color.appInk)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(BMPressStyle())
        .disabled(loading)
    }
}

struct BMSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            HStack(spacing: Space.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.bmUI(15, weight: .semibold))
                }
                Text(title)
                    .font(.bmUI(16, weight: .semibold))
            }
            .foregroundStyle(Color.appInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.vertical, Space.xs)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
        .buttonStyle(BMPressStyle())
    }
}

struct BMIconButton: View {
    let icon: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 15
    var fg: Color = Color.appInk
    var bg: Color = Color.appSurface
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            Image(systemName: icon)
                .font(.bmUI(iconSize, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: size, height: size)
                .background(bg, in: Circle())
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))
        }
        .buttonStyle(BMIconPressStyle())
    }
}

// MARK: - Chips

struct BMChip: View {
    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            if onTap != nil { Haptic.select() }
            onTap?()
        } label: {
            HStack(spacing: Space.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.bmUI(11, weight: .semibold))
                }
                Text(title)
                    .font(.bmUI(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.appInkInverse : Color.appInk)
            .padding(.horizontal, Space.sm)
            .frame(minHeight: 32)
            .padding(.vertical, 6)
            .background(isSelected ? Color.appAccent : Color.appSurface, in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.96))
        .disabled(onTap == nil)
    }
}

struct BMTag: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Color.appInk
    var bg: Color = Color.appSurface

    var body: some View {
        HStack(spacing: Space.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.bmUI(11, weight: .semibold))
            }
            Text(text)
                .font(.bmUI(12, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Space.xs)
        .frame(minHeight: 26)
        .padding(.vertical, 4)
        .background(bg, in: Capsule())
    }
}

// MARK: - Rating

struct BMRatingLine: View {
    let rating: Double
    let count: Int
    var size: CGFloat = 13
    var showsStars: Bool = true

    var body: some View {
        HStack(spacing: Space.xxs) {
            if showsStars {
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < rating.rounded() ? "star.fill" : "star")
                            .font(.bmUI(10, weight: .medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            Text(String(format: "%.1f", rating))
                .font(.bmMono(size, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("·")
                .font(.bmMono(size))
                .foregroundStyle(Color.appSmoke)
            Text("\(count)")
                .font(.bmMono(size, weight: .medium))
                .foregroundStyle(Color.appAsh)
        }
    }
}

struct BMPriceTag: View {
    let price: Int
    var prefix: String = "from"

    var body: some View {
        HStack(spacing: Space.xxs) {
            Text(prefix)
                .font(.bmUI(11, weight: .medium))
                .foregroundStyle(Color.appSmoke)
            Text("£\(price)")
                .font(.bmMono(15, weight: .semibold))
                .foregroundStyle(Color.appAccent)
        }
    }
}

// MARK: - Divider

struct BMDivider: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// MARK: - Section label

struct BMSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.bmUI(11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Color.appAsh)
    }
}

// MARK: - Empty state

struct BMEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (label: String, handler: () -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.bmUI(32, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }

            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Space.xl)
            }

            if let action {
                Button {
                    Haptic.press()
                    action.handler()
                } label: {
                    Text(action.label)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 44)
                        .padding(.vertical, 6)
                        .background(Color.appAccent, in: Capsule())
                }
                .buttonStyle(BMPressStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}

// MARK: - Loading

struct BMLoadingView: View {
    var message: String = "Loading"
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 6, height: 6)
                        .opacity(reduceMotion ? 0.6 : (animating ? 0.3 : 1))
                        .animation(
                            reduceMotion
                                ? .default
                                : .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            Text(message)
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
        }
        .onAppear {
            if !reduceMotion { animating = true }
        }
    }
}

// MARK: - Avatar

struct BMAvatar: View {
    let url: String
    var size: CGFloat = 44
    var ringed: Bool = false
    var initials: String? = nil

    var body: some View {
        ZStack {
            if url.isEmpty {
                Circle()
                    .fill(Color.appAccentTint)
                    .overlay(
                        Text(initials ?? "·")
                            .font(.bmDisplay(size * 0.4, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    )
            } else {
                RemoteImage(url: url)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }

            if ringed {
                Circle()
                    .stroke(Color.appAccent, lineWidth: 2)
                    .frame(width: size + 4, height: size + 4)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Skeleton

struct BMSkeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4
    @State private var phase: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.appSurface.opacity(0.5), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .offset(x: reduceMotion ? 0 : phase * 400)
                .blendMode(.overlay)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1.6
                    }
                }
            }
    }
}