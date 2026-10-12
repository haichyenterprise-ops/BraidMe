import SwiftUI

// MARK: - Shared booking chrome

/// Back/close button plus a three-step braid-gradient progress bar.
struct BookingTopBar: View {
    let step: Int
    var total: Int = 3
    var icon: String = "chevron.left"
    let onBack: () -> Void

    private let labels = ["Service", "Time", "Confirm"]

    private var stepLabel: String {
        let i = step - 1
        return labels.indices.contains(i) ? labels[i] : ""
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                BMIconButton(icon: icon, size: 42, iconSize: 14, action: onBack)
                VStack(alignment: .leading, spacing: 6) {
                    BookingProgressHeader(step: step, total: total)
                    Text("Step \(step) of \(total): \(stepLabel)")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.bmTextDim)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
    }
}

struct BookingProgressHeader: View {
    let step: Int
    var total: Int = 3
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(LinearGradient.bmBraidGradient)
                                .frame(width: i < shown ? geo.size.width : 0)
                                .animation(Motion.reveal.delay(Double(i) * 0.12), value: shown)
                        }
                    }
            }
        }
        .onAppear { shown = step }
        .onChange(of: step) { _, new in shown = new }
    }
}

// MARK: - Service selection

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
                AuroraBackground(intensity: 0.5)

                VStack(spacing: 0) {
                    BookingTopBar(step: 1, icon: "xmark") { dismiss() }
                    header
                    list
                }

                if let service = selectedService {
                    continueBar(service: service)
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, Space.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDateTime) {
                if let service = selectedService {
                    BookingDateTimeView(braider: braider, service: service)
                }
            }
        }
        .task {
            appeared = true
            if let preselect = preselectServiceId {
                selectedId = preselect
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Choose a service")
                .font(.bmDisplay(36, weight: .semibold))
                .foregroundStyle(Color.bmText)
            HStack(spacing: Space.xs) {
                BMAvatar(url: braider.avatarUrl, size: 24, initials: bmInitials(braider.name))
                Text("with \(braider.name)")
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .reveal(appeared, offset: 16)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Space.sm) {
                if services.isEmpty {
                    BMEmptyState(
                        icon: "calendar.badge.exclamationmark",
                        title: "No services yet",
                        message: "This braider hasn't listed any services to book."
                    )
                }
                ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                    ServiceSelectableCard(
                        service: service,
                        isSelected: selectedId == service.id,
                        onTap: {
                            Haptic.select()
                            withAnimation(Motion.sheet) {
                                selectedId = selectedId == service.id ? nil : service.id
                            }
                        }
                    )
                    .reveal(appeared, delay: Motion.stagger(index) + 0.08, offset: 24, blur: 0)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 130)
        }
    }

    private func continueBar(service: BraidService) -> some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.bmUI(14, weight: .bold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(1)
                Text("from £\(service.priceFrom)")
                    .font(.bmNum(13, weight: .bold))
                    .foregroundStyle(Color.bmGilt)
            }
            Spacer(minLength: 0)
            Button {
                Haptic.press()
                showDateTime = true
            } label: {
                HStack(spacing: Space.xs) {
                    Text("Continue")
                        .font(.bmUI(15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.bmUI(13, weight: .bold))
                }
                .foregroundStyle(Color.bmOnGilt)
                .padding(.horizontal, Space.lg)
                .frame(height: 52)
                .background(LinearGradient.bmGiltGradient, in: Capsule())
            }
            .buttonStyle(BMPressStyle())
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.xs)
        .padding(.vertical, Space.xs)
        .bmGlass(radius: 40, tint: Color.black.opacity(0.3))
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
    }
}

// MARK: - Service card

struct ServiceSelectableCard: View {
    let service: BraidService
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: Space.md) {
                    thumb

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(service.name)
                                .font(.bmDisplay(19, weight: .semibold))
                                .foregroundStyle(Color.bmText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if service.popular {
                                Image(systemName: "flame.fill")
                                    .font(.bmUI(12, weight: .bold))
                                    .foregroundStyle(Color.bmEmber)
                            }
                        }
                        HStack(spacing: Space.sm) {
                            Text("£\(service.priceFrom)")
                                .font(.bmNum(15, weight: .bold))
                                .foregroundStyle(Color.bmGilt)
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.bmUI(11, weight: .semibold))
                                Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                    .font(.bmUI(12, weight: .medium))
                            }
                            .foregroundStyle(Color.bmTextDim)
                        }
                    }

                    Spacer(minLength: 0)

                    indicator
                }

                if isSelected && (!service.description.isEmpty || !service.includes.isEmpty) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        BMDivider().padding(.top, Space.md)
                        if !service.description.isEmpty {
                            Text(service.description)
                                .font(.bmUI(14))
                                .foregroundStyle(Color.bmTextDim)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !service.includes.isEmpty {
                            FlowLayout(spacing: Space.xs) {
                                ForEach(service.includes, id: \.self) { item in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.bmUI(9, weight: .bold))
                                            .foregroundStyle(Color.bmGilt)
                                        Text(item)
                                            .font(.bmUI(12, weight: .semibold))
                                            .foregroundStyle(Color.bmText)
                                    }
                                    .padding(.horizontal, Space.sm)
                                    .frame(height: 28)
                                    .background(Color.bmGilt.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard(radius: Radius.card, fill: isSelected ? Color.bmRaised : Color.bmSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.bmGilt.opacity(0.8) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .shadow(color: isSelected ? Color.bmGilt.opacity(0.22) : Color.clear, radius: 18, y: 6)
        }
        .buttonStyle(BMPressStyle(scale: 0.985, dim: 0.02))
    }

    private var thumb: some View {
        ZStack {
            if service.imageUrl.isEmpty {
                LinearGradient(
                    colors: [Color.bmRaised, Color.bmSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles")
                    .font(.bmUI(22, weight: .light))
                    .foregroundStyle(LinearGradient.bmGiltGradient)
            } else {
                RemoteImage(url: service.imageUrl)
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.22), lineWidth: 1.5)
                .frame(width: 28, height: 28)
            if isSelected {
                Circle()
                    .fill(LinearGradient.bmGiltGradient)
                    .frame(width: 28, height: 28)
                    .transition(.scale)
                Image(systemName: "checkmark")
                    .font(.bmUI(12, weight: .heavy))
                    .foregroundStyle(Color.bmOnGilt)
                    .transition(.scale)
            }
        }
        .animation(Motion.pop, value: isSelected)
    }
}
