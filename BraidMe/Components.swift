import SwiftUI

// =============================================================================
// Shared components — buttons, chips, fields, avatars, states.
// =============================================================================

/// Two-letter initials for any display name.
func bmInitials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    return r.isEmpty ? "·" : r.uppercased()
}

// MARK: - Buttons

struct BMPrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var loading: Bool = false
    var shine: Bool = true
    var action: () -> Void

    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            ZStack {
                HStack(spacing: Space.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.bmUI(15, weight: .bold))
                    }
                    VStack(spacing: 1) {
                        Text(title)
                            .font(.bmUI(16, weight: .bold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.bmUI(11, weight: .medium))
                                .opacity(0.7)
                        }
                    }
                }
                .opacity(loading ? 0 : 1)

                if loading {
                    BMSpinner(color: Color.bmOnGilt)
                }
            }
            .foregroundStyle(Color.bmOnGilt)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background(LinearGradient.bmGiltGradient)
            .overlay { shineLayer }
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8)
            )
            .shadow(color: Color.bmGilt.opacity(0.32), radius: 18, y: 8)
        }
        .buttonStyle(BMPressStyle())
        .disabled(loading)
        .onAppear {
            guard shine, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.8)) {
                sweep = true
            }
        }
    }

    private var shineLayer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.45), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.45)
            .offset(x: sweep ? geo.size.width * 1.1 : -geo.size.width * 0.6)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .opacity(shine ? 1 : 0)
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
            .foregroundStyle(Color.bmText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .bmGlass(radius: Radius.button)
        }
        .buttonStyle(BMPressStyle())
    }
}

struct BMIconButton: View {
    let icon: String
    var size: CGFloat = 42
    var iconSize: CGFloat = 15
    var fg: Color = Color.bmText
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
                .bmGlassCircle()
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
                        .font(.bmUI(11, weight: .bold))
                }
                Text(title)
                    .font(.bmUI(13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.bmOnGilt : Color.bmText)
            .padding(.horizontal, Space.md)
            .frame(minHeight: 38)
            .background {
                if isSelected {
                    Capsule().fill(LinearGradient.bmGiltGradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.12),
                    lineWidth: 0.8
                )
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.95))
        .disabled(onTap == nil)
        .animation(Motion.press, value: isSelected)
    }
}

struct BMTag: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Color.bmGilt

    var body: some View {
        HStack(spacing: Space.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.bmUI(10, weight: .bold))
            }
            Text(text)
                .font(.bmUI(12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Space.sm)
        .frame(minHeight: 28)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Rating

struct BMStars: View {
    let rating: Double
    var size: CGFloat = 11
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: Double(i) < rating.rounded() ? "star.fill" : "star")
                    .font(.bmUI(size, weight: .semibold))
                    .foregroundStyle(
                        Double(i) < rating.rounded() ? Color.bmGilt : Color.bmTextFaint
                    )
            }
        }
    }
}

struct BMRatingLine: View {
    let rating: Double
    let count: Int
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.bmUI(size - 1, weight: .bold))
                .foregroundStyle(Color.bmGilt)
            Text(String(format: "%.1f", rating))
                .font(.bmNum(size, weight: .bold))
                .foregroundStyle(Color.bmText)
            Text("(\(count))")
                .font(.bmNum(size - 1, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
        }
    }
}

struct BMPriceTag: View {
    let price: Int
    var prefix: String = "from"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(prefix)
                .font(.bmUI(11, weight: .medium))
                .foregroundStyle(Color.bmTextFaint)
            Text("£\(price)")
                .font(.bmNum(16, weight: .bold))
                .foregroundStyle(Color.bmGilt)
        }
    }
}

// MARK: - Dividers / labels

struct BMDivider: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Color.bmLine)
            .frame(height: 0.6)
            .padding(.leading, inset)
    }
}

struct BMSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.bmUI(13, weight: .semibold))
            .foregroundStyle(Color.bmTextDim)
    }
}

/// Large serif heading with an optional trailing accessory.
struct BMSectionHeading<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bmDisplay(26, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                if let subtitle {
                    Text(subtitle)
                        .font(.bmUI(13))
                        .foregroundStyle(Color.bmTextDim)
                }
            }
            Spacer(minLength: Space.sm)
            trailing()
        }
    }
}

extension BMSectionHeading where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

/// Header used at the top of modal sheets.
struct BMSheetBar: View {
    let title: String
    var subtitle: String? = nil
    var icon: String = "xmark"
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bmDisplay(30, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.bmUI(14))
                        .foregroundStyle(Color.bmTextDim)
                }
            }
            Spacer(minLength: 0)
            BMIconButton(icon: icon, size: 40, iconSize: 13, action: onClose)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
    }
}

// MARK: - Orb + empty / loading

struct BMOrb: View {
    let icon: String
    var size: CGFloat = 96
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.bmGilt.opacity(0.28))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.28)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.bmRaised, Color.bmSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )

            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .light))
                .foregroundStyle(LinearGradient.bmGiltGradient)
        }
        .frame(width: size, height: size)
        .offset(y: float ? -5 : 5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}

struct BMEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (label: String, handler: () -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.lg) {
            BMOrb(icon: icon)

            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.bmUI(14))
                    .foregroundStyle(Color.bmTextDim)
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
                        .font(.bmUI(14, weight: .bold))
                        .foregroundStyle(Color.bmOnGilt)
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 46)
                        .background(LinearGradient.bmGiltGradient, in: Capsule())
                }
                .buttonStyle(BMPressStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}

struct BMLoadingView: View {
    var message: String = "Loading"
    var edge: Color = Color.bmBase

    var body: some View {
        VStack(spacing: Space.md) {
            BraidMark(length: 74, thickness: 30, strand: 7, horizontal: true, cycles: 1.6, edge: edge)
            Text(message)
                .font(.bmUI(13, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
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
                    .fill(
                        LinearGradient(
                            colors: [Color.bmRaised, Color.bmSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials ?? "·")
                            .font(.bmDisplay(size * 0.4, weight: .semibold))
                            .foregroundStyle(LinearGradient.bmGiltGradient)
                    )
            } else {
                RemoteImage(url: url)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }

            if ringed {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [Color.bmGilt, Color.bmEmber, Color.bmOrchid, Color.bmGilt],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size + 7, height: size + 7)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Skeleton

struct BMSkeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.bmRaised)
            .frame(height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Text fields

struct BMFieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.bmUI(15, weight: .medium))
                .foregroundStyle(text.isEmpty ? Color.bmTextFaint : Color.bmGilt)
                .frame(width: 20)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundColor(Color.bmTextFaint)
            )
            .font(.bmUI(16, weight: .medium))
            .foregroundStyle(Color.bmText)
            .tint(Color.bmGilt)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .submitLabel(submitLabel)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(true)

            if !text.isEmpty {
                Button {
                    Haptic.select()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.bmTextFaint)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 58)
        .background(Color.bmSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(
                    text.isEmpty ? Color.white.opacity(0.09) : Color.bmGilt.opacity(0.55),
                    lineWidth: 1
                )
        )
        .animation(Motion.subtle, value: text.isEmpty)
    }
}

struct BMPasswordRow: View {
    let placeholder: String
    @Binding var text: String
    var isNew: Bool = false

    @State private var show = false

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "lock")
                .font(.bmUI(15, weight: .medium))
                .foregroundStyle(text.isEmpty ? Color.bmTextFaint : Color.bmGilt)
                .frame(width: 20)

            Group {
                if show {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(Color.bmTextFaint)
                    )
                } else {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(Color.bmTextFaint)
                    )
                }
            }
            .font(.bmUI(16, weight: .medium))
            .foregroundStyle(Color.bmText)
            .tint(Color.bmGilt)
            .textContentType(isNew ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                Haptic.select()
                show.toggle()
            } label: {
                Image(systemName: show ? "eye.slash" : "eye")
                    .font(.bmUI(15, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 58)
        .background(Color.bmSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(
                    text.isEmpty ? Color.white.opacity(0.09) : Color.bmGilt.opacity(0.55),
                    lineWidth: 1
                )
        )
        .animation(Motion.subtle, value: text.isEmpty)
    }
}
