import SwiftUI

// =============================================================================
// Components — Shared UI primitives, upgraded
// =============================================================================

// ═══════════════════════════════════════════════════════════════════
// MARK: - Primary Button
// ═══════════════════════════════════════════════════════════════════

struct BMPrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var loading: Bool = false
    var action: () -> Void

    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.appInk)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                HStack(spacing: Space.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.65)
                        }
                    }
                }
                .foregroundStyle(Color.appInkInverse)
                .opacity(loading ? 0 : 1)

                if loading {
                    ProgressView()
                        .tint(Color.appInkInverse)
                        .scaleEffect(1.1)
                }

                if !loading {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: shimmerPhase * geo.size.width * 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .shadow(color: Color.appInk.opacity(0.2), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { isPressed = false } }
        )
        .disabled(loading)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(1)) {
                shimmerPhase = 1.5
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Secondary Button
// ═══════════════════════════════════════════════════════════════════

struct BMSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            HStack(spacing: Space.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.appInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { isPressed = false } }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Press Styles
// ═══════════════════════════════════════════════════════════════════

struct BMPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.04
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -dim : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct BMIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct BMSquirclePressStyle: ButtonStyle {
    var scale: CGFloat = 0.965
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.38, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Rating Line
// ═══════════════════════════════════════════════════════════════════

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
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.gold)
                    }
                }
            }
            Text(String(format: "%.1f", rating))
                .font(.system(size: size, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.appInk)
            Text("·")
                .font(.system(size: size, design: .monospaced))
                .foregroundStyle(Color.appSmoke)
            Text("\(count)")
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.appAsh)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Price Tag
// ═══════════════════════════════════════════════════════════════════

struct BMPriceTag: View {
    let price: Int
    var prefix: String = "from"

    var body: some View {
        HStack(spacing: Space.xxs) {
            Text(prefix)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.appSmoke)
            Text("£\(price)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.gold)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Divider
// ═══════════════════════════════════════════════════════════════════

struct BMDivider: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.appDivider.opacity(0), Color.appDivider, Color.appDivider.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Check Shape
// ═══════════════════════════════════════════════════════════════════

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.80))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.20))
        return path
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FlowLayout
// ═══════════════════════════════════════════════════════════════════

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Empty State
// ═══════════════════════════════════════════════════════════════════

struct BMEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (label: String, handler: () -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.gold)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Space.xl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            if let action {
                Button {
                    Haptic.press()
                    action.handler()
                } label: {
                    Text(action.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 48)
                        .background(Color.appInk, in: Capsule())
                        .shadow(color: Color.appInk.opacity(0.2), radius: 12, y: 4)
                }
                .buttonStyle(BMPressStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Loading View
// ═══════════════════════════════════════════════════════════════════

struct BMLoadingView: View {
    var message: String = "Loading"
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gold)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .opacity(animating ? 0.4 : 1)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appAsh)
        }
        .onAppear {
            if !reduceMotion { animating = true }
        }
    }
}