import SwiftUI

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
                    colors: [Color.appAccent.opacity(0.06), .clear],
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
                    BMGlassIconButton(icon: "xmark", size: 40, iconSize: 14, tint: .appInk) {
                        dismiss()
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
            withAnimation(Motion.heroReveal.delay(0.1)) { appeared = true }
            if let preselect = preselectServiceId {
                selectedId = preselect
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 20, height: 2)
                Text("STEP 1 OF 3")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAccent)
            }

            Text("Choose a service")
                .font(.bmHero(34))
                .foregroundStyle(Color.appInk)
                .lineSpacing(-4)

            HStack(spacing: Space.xs) {
                BMAvatar(url: braider.avatarUrl, size: 24, initials: "")
                Text("with \(braider.name)")
                    .font(.bmUI(14))
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

    private var list: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: Space.sm) {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                    ServiceSelectableCard(
                        service: service,
                        isSelected: selectedId == service.id,
                        onTap: {
                            Haptic.select()
                            withAnimation(Motion.bouncy) {
                                selectedId = selectedId == service.id ? nil : service.id
                            }
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animate(Motion.reveal.delay(0.15 + Motion.stagger(index)), value: appeared)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 140)
        }
    }

    private func continueBar(service: BraidService) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.appDivider.opacity(0), Color.appDivider, Color.appDivider.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("from £\(service.priceFrom)")
                        .font(.bmMono(13, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Button {
                    Haptic.press()
                    showDateTime = true
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Continue")
                            .font(.bmUI(15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.bmUI(12, weight: .bold))
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
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Progress Header

struct BookingProgressHeader: View {
    let step: Int
    var total: Int = 3

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<total, id: \.self) { i in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appDivider)
                        .frame(height: 4)
                    if i < step {
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(height: 4)
                    }
                }
                .animation(Motion.smooth, value: step)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
    }
}

// MARK: - Service Selectable Card

struct ServiceSelectableCard: View {
    let service: BraidService
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Space.md) {
                    ZStack {
                        if service.imageUrl.isEmpty {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appSurfaceElevated)
                                .frame(width: 80, height: 80)
                            Image(systemName: "photo")
                                .font(.bmUI(24))
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
                                .font(.bmUI(16, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .lineLimit(1)
                            if service.popular {
                                Image(systemName: "flame.fill")
                                    .font(.bmUI(11))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        HStack(spacing: Space.xs) {
                            Text("£\(service.priceFrom)")
                                .font(.bmMono(15, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                            Text("·")
                                .foregroundStyle(Color.appSmoke)
                            Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                .font(.bmUI(13))
                                .foregroundStyle(Color.appAsh)
                        }
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: 2)
                            .frame(width: 26, height: 26)
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.bmUI(11, weight: .bold))
                                .foregroundStyle(Color.appInkInverse)
                        }
                    }
                    .animation(Motion.bouncy, value: isSelected)
                }

                if isSelected && !service.description.isEmpty {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        BMDivider().padding(.top, Space.md)
                        Text(service.description)
                            .font(.bmUI(14))
                            .foregroundStyle(Color.appAsh)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        if !service.includes.isEmpty {
                            FlowLayout(spacing: Space.xs) {
                                ForEach(service.includes, id: \.self) { item in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.bmUI(9, weight: .bold))
                                            .foregroundStyle(Color.appAccent)
                                        Text(item)
                                            .font(.bmUI(11, weight: .medium))
                                            .foregroundStyle(Color.appInk)
                                    }
                                    .padding(.horizontal, Space.xs)
                                    .frame(minHeight: 26)
                                    .padding(.vertical, 4)
                                    .background(Color.appAccentTint, in: Capsule())
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
                        isSelected ? Color.appAccent : Color.appDivider,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.appAccent.opacity(0.15) : Color.appInk.opacity(0.04),
                radius: isSelected ? 16 : 8,
                y: isSelected ? 6 : 2
            )
            .animation(Motion.bouncy, value: isSelected)
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}