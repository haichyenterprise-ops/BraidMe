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

                VStack(spacing: 0) {
                    BookingProgressHeader(step: 1)
                    header
                    list
                }

                if let service = selectedService {
                    continueBar(service: service)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BMIconButton(icon: "xmark", size: 36, iconSize: 13) { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                .font(.bmDisplay(30, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("with \(braider.name)")
                .font(.bmUI(14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animate(Motion.reveal, value: appeared)
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
                            withAnimation(Motion.press) {
                                selectedId = selectedId == service.id ? nil : service.id
                            }
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 120)
        }
    }

    private func continueBar(service: BraidService) -> some View {
        VStack(spacing: 0) {
            BMDivider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("from £\(service.priceFrom)")
                        .font(.bmMono(12, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Button {
                    Haptic.press()
                    showDateTime = true
                } label: {
                    Text("Continue")
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 48)
                        .background(Color.appInk, in: Capsule())
                }
                .buttonStyle(BMPressStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Color.appSurface)
        }
    }
}

// MARK: - Progress header

struct BookingProgressHeader: View {
    let step: Int
    var total: Int = 3

    var body: some View {
        HStack(spacing: Space.xxs) {
            ForEach(0..<total, id: \.self) { i in
                Rectangle()
                    .fill(i < step ? Color.appAccent : Color.appDivider)
                    .frame(height: 3)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
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
                HStack(alignment: .top, spacing: Space.md) {
                    ZStack {
                        if service.imageUrl.isEmpty {
                            RoundedRectangle(cornerRadius: Radius.button)
                                .fill(Color.appDivider)
                                .frame(width: 72, height: 72)
                            Image(systemName: "photo")
                                .font(.bmUI(22))
                                .foregroundStyle(Color.appSmoke)
                        } else {
                            RemoteImage(url: service.imageUrl)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: Space.xxs) {
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
                                .font(.bmMono(14, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                            Text("·")
                                .foregroundStyle(Color.appSmoke)
                            Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                .font(.bmUI(12))
                                .foregroundStyle(Color.appAsh)
                        }
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.bmUI(11, weight: .bold))
                                .foregroundStyle(Color.appInkInverse)
                        }
                    }
                }

                if isSelected && !service.description.isEmpty {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        BMDivider().padding(.top, Space.md)
                        Text(service.description)
                            .font(.bmUI(14))
                            .foregroundStyle(Color.appAsh)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if !service.includes.isEmpty {
                            FlowLayout(spacing: Space.xs) {
                                ForEach(service.includes, id: \.self) { item in
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark")
                                            .font(.bmUI(9, weight: .bold))
                                            .foregroundStyle(Color.appAccent)
                                        Text(item)
                                            .font(.bmUI(11, weight: .medium))
                                            .foregroundStyle(Color.appInk)
                                    }
                                    .padding(.horizontal, Space.xs)
                                    .frame(minHeight: 24)
                                    .padding(.vertical, 3)
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
                    .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}