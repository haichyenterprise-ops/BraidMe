import SwiftUI

// =============================================================================
// Premium Components — High-tech, luxurious UI elements
// =============================================================================

// MARK: - Primary Button

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
                // Background
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.appInk)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Content
                HStack(spacing: Space.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.bmUI(15, weight: .semibold))
                            .transition(.scale.combined(with: .opacity))
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
                .foregroundStyle(Color.appInkInverse)
                .opacity(loading ? 0 : 1)
                
                // Loading
                if loading {
                    ProgressView()
                        .tint(Color.appInkInverse)
                        .scaleEffect(1.1)
                }
                
                // Shimmer overlay
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
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
        .disabled(loading)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(1)) {
                shimmerPhase = 1.5
            }
        }
    }
}

// MARK: - Secondary Button

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
                        .font(.bmUI(15, weight: .semibold))
                }
                Text(title)
                    .font(.bmUI(16, weight: .semibold))
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
            .shadow(color: Color.appInk.opacity(0.04), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
    }
}

// MARK: - Icon Button

struct BMIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 16
    var fg: Color = .appInk
    var bg: Color = .appSurface
    var action: () -> Void
    
    @State private var isPressed = false
    
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
                .shadow(color: Color.appInk.opacity(0.06), radius: 8, y: 2)
                .scaleEffect(isPressed ? 0.90 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
    }
}

// MARK: - Glass Icon Button

struct BMGlassIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 16
    var tint: Color = .white
    var action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            Haptic.press()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .scaleEffect(isPressed ? 0.90 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
    }
}

// MARK: - Chip

struct BMChip: View {
    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    @State private var isPressed = false
    
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
            .frame(minHeight: 36)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.appInk)
                    } else {
                        Capsule().fill(Color.appSurface)
                    }
                }
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: isSelected ? Color.appInk.opacity(0.15) : .clear, radius: 8, y: 2)
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
        .disabled(onTap == nil)
    }
}

// MARK: - Tag

struct BMTag: View {
    let text: String
    var icon: String? = nil
    var tint: Color = .appInk
    var bg: Color = .appSurfaceElevated
    
    var body: some View {
        HStack(spacing: Space.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.bmUI(10, weight: .semibold))
            }
            Text(text)
                .font(.bmUI(11, weight: .semibold))
                .tracking(0.3)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Space.xs)
        .frame(minHeight: 24)
        .background(bg, in: Capsule())
    }
}

// MARK: - Rating Line

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
                            .font(.bmUI(9, weight: .medium))
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

// MARK: - Price Tag

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

// MARK: - Section Label

struct BMSectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: Space.xs) {
            Rectangle()
                .fill(Color.appAccent)
                .frame(width: 16, height: 2)
            Text(text.uppercased())
                .font(.bmUI(11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.appAsh)
        }
    }
}

// MARK: - Empty State

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
                    .fill(Color.appAccentTint)
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.bmUI(36, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.bmUI(14))
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
                        .font(.bmUI(14, weight: .semibold))
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
            withAnimation(Motion.reveal.delay(0.1)) { appeared = true }
        }
    }
}

// MARK: - Loading View

struct BMLoadingView: View {
    var message: String = "Loading"
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.appAccent)
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
                .font(.bmUI(13, weight: .medium))
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
    var initials: String? = nil
    var ringed: Bool = false
    var glow: Bool = false
    
    var body: some View {
        ZStack {
            if url.isEmpty {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccentTint, Color.appAccent.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                    .stroke(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size + 6, height: size + 6)
            }
        }
        .frame(width: size, height: size)
        .shadow(
            color: glow ? Color.appAccent.opacity(0.4) : Color.clear,
            radius: glow ? 12 : 0,
            y: glow ? 4 : 0
        )
    }
}

// MARK: - Skeleton

struct BMSkeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 6
    @State private var phase: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.appDivider)
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.appSurface.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: reduceMotion ? 0 : phase * geo.size.width * 1.5)
                    .blendMode(.overlay)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
            }
    }
}

// MARK: - Stat Card

struct BMStatCard: View {
    let value: String
    let label: String
    var icon: String? = nil
    var accent: Color = .appAccent
    
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: Space.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            Text(value)
                .font(.bmDisplay(24, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.bmUI(9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(Motion.reveal) { appeared = true }
        }
    }
}

// MARK: - Progress Ring

struct BMProgressRing: View {
    let progress: CGFloat
    var size: CGFloat = 60
    var lineWidth: CGFloat = 4
    var color: Color = .appAccent
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appDivider, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Motion.smooth, value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animated Checkmark

struct BMAnimatedCheckmark: View {
    var size: CGFloat = 60
    var color: Color = .appSignal
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            CheckShape()
                .trim(from: 0, to: trimEnd)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.45, height: size * 0.45)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(Motion.bouncy) {
                scale = 1
                opacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                trimEnd = 1
            }
        }
    }
}




// MARK: - Floating Action Button

struct BMFloatingButton: View {
    let icon: String
    var size: CGFloat = 56
    var action: () -> Void
    
    @State private var isPressed = false
    @State private var pulse = false
    
    var body: some View {
        Button(action: {
            Haptic.medium()
            action()
        }) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.4 : 1)
                    .opacity(pulse ? 0 : 0.8)
                
                // Main button
                Circle()
                    .fill(Color.appInk)
                    .frame(width: size, height: size)
                    .shadow(color: Color.appInk.opacity(0.3), radius: 16, y: 8)
                
                Image(systemName: icon)
                    .font(.bmUI(20, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
            }
            .scaleEffect(isPressed ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Motion.press) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { isPressed = false }
                }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}