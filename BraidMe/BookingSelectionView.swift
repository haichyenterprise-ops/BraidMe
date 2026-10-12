import SwiftUI

// =============================================================================
// BookingSelectionView — Step 1: choose a service, upgraded
// Shimmer progress bars, expandable cards with spring, ambient gradient.
// =============================================================================

struct BookingSelectionView: View {
    let braider: Braider
    var preselectServiceId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedId: String?
    @State private var appeared = false
    @State private var showDateTime = false

    private var services: [BraidService] { braider.services }

    private var selectedService: BraidService? {
        guard let id = selectedId else { return nil }
        return services.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                // Ambient gradient
                RadialGradient(
                    colors: [Color.gold.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    BookingProgressHeader(step: 1)
                    header
                    list
                }

                if let service = selectedService {
                    continueBar(service: service)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDateTime) {
                if let service = selectedService {
                    BookingDateTimeView(braider: braider, service: service)
                }
            }
        }
        .task {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            if let preselect = preselectServiceId {
                selectedId = preselect
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 2)
                Text("STEP 1 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.gold)
            }

            Text("Choose a service")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            HStack(spacing: Space.xs) {
                if braider.avatarUrl.isEmpty {
                    Circle()
                        .fill(Color.gold.opacity(0.18))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(braider.initials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.gold)
                        )
                } else {
                    RemoteImage(url: braider.avatarUrl)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
                Text("with \(braider.name)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - List

    private var list: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: Space.sm) {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                    ServiceSelectableCard(
                        service: service,
                        isSelected: selectedId == service.id,
                        onTap: {
                            Haptic.select()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                selectedId = selectedId == service.id ? nil : service.id
                            }
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.85)
                            .delay(0.15 + Double(index) * 0.06),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 140)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Continue bar

    private func continueBar(service: BraidService) -> some View {
        VStack(spacing: 0) {
            // Gold hairline
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.gold.opacity(0.5), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("from £\(service.priceFrom)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.gold)
                }
                Spacer()
                Button {
                    Haptic.press()
                    showDateTime = true
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Continue")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: 52)
                    .background(Color.appInk, in: Capsule())
                    .shadow(color: Color.appInk.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(BMPressStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Color.glassTintStrong)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Progress Header
// ═══════════════════════════════════════════════════════════════════

struct BookingProgressHeader: View {
    let step: Int
    var total: Int = 3

    @State private var shimmerPosition: CGFloat = -1

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<total, id: \.self) { i in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appDivider)
                        .frame(height: 4)
                    if i < step {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.goldLight, Color.gold, Color.goldDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 4)
                            .overlay(
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, .white.opacity(0.6), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * 0.4)
                                        .offset(x: shimmerPosition * geo.size.width * 1.4)
                                        .blendMode(.overlay)
                                }
                                .clipShape(Capsule())
                            )
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                shimmerPosition = 1
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Service Selectable Card
// ═══════════════════════════════════════════════════════════════════

struct ServiceSelectableCard: View {
    let service: BraidService
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Space.md) {
                    // Thumbnail
                    ZStack {
                        if service.imageUrl.isEmpty {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appSurfaceElevated)
                                .frame(width: 80, height: 80)
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.appSmoke)
                        } else {
                            RemoteImage(url: service.imageUrl)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: Space.xs) {
                            Text(service.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .lineLimit(1)
                            if service.popular {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.gold)
                            }
                        }
                        HStack(spacing: Space.xs) {
                            Text("£\(service.priceFrom)")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.gold)
                            Text("·")
                                .foregroundStyle(Color.appSmoke)
                            Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appAsh)
                        }
                    }

                    Spacer(minLength: 0)

                    // Selection circle
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.gold : Color.appDivider, lineWidth: 2)
                            .frame(width: 26, height: 26)
                        if isSelected {
                            Circle()
                                .fill(Color.gold)
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.appInkInverse)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isSelected)
                }

                // Expanded content
                if isSelected && !service.description.isEmpty {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        BMDivider().padding(.top, Space.md)

                        Text(service.description)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appAsh)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        if !service.includes.isEmpty {
                            FlowLayout(spacing: Space.xs) {
                                ForEach(service.includes, id: \.self) { item in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.gold)
                                        Text(item)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.appInk)
                                    }
                                    .padding(.horizontal, Space.xs)
                                    .frame(minHeight: 26)
                                    .padding(.vertical, 4)
                                    .background(Color.gold.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(Space.md)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(
                        isSelected ? Color.gold : Color.appDivider,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.gold.opacity(0.15) : Color.black.opacity(0.04),
                radius: isSelected ? 16 : 8,
                y: isSelected ? 6 : 2
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}