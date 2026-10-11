import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @State private var selectedId: String?
    @State private var showPayment = false
    @State private var appeared = false

    private var services: [BraidService] { braider.services }

    private var selectedService: BraidService? {
        guard let id = selectedId else { return nil }
        return services.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 22)

                        if services.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 18) {
                                ForEach(services) { service in
                                    ExpandingServiceCard(
                                        service: service,
                                        isSelected: selectedId == service.id,
                                        onTap: { toggleSelect(service) }
                                    )
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 180)
                        }
                    }
                }

                VStack {
                    Spacer()
                    bottomCTA
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.snow)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.5))
                    }
                    .buttonStyle(BouncyPress())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPayment) {
                if let service = selectedService {
                    PaymentView(braider: braider, service: service)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                Text("SELECT A SERVICE")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("What are you\nlooking for?")
                .font(AppTheme.serif(34))
                .lineSpacing(-2)
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("with")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.stone)
                Text(braider.name)
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppTheme.ash)
            Text("No services available")
                .font(AppTheme.serif(20))
                .foregroundColor(AppTheme.ink)
            Text("This braider hasn't listed any services yet.")
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.slate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if let service = selectedService {
                HStack(spacing: 10) {
                    Text("Selected")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.stone)
                    Text(service.name)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Spacer()
                    Text("£\(service.priceFrom)")
                        .font(AppTheme.serif(18))
                        .foregroundColor(AppTheme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.mist)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            PrimaryButton(title: "Continue", icon: "arrow.right") {
                showPayment = true
            }
            .disabled(selectedService == nil)
            .opacity(selectedService == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud, AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedId)
    }

    private func toggleSelect(_ service: BraidService) {
        Haptics.select()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            if selectedId == service.id {
                selectedId = nil
            } else {
                selectedId = service.id
            }
        }
    }
}

// MARK: - Service card

struct ExpandingServiceCard: View {
    let service: BraidService
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageBlock
                details
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.4),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.ink.opacity(0.15) : .black.opacity(0.06),
                radius: isSelected ? 24 : 12,
                y: isSelected ? 12 : 6
            )
        }
        .buttonStyle(CardPress())
    }

    private var imageBlock: some View {
        ZStack(alignment: .topLeading) {
            if service.imageUrl.isEmpty {
                RoundedRectangle(cornerRadius: 26)
                    .fill(AppTheme.mist)
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.ash)
                    )
            } else {
                RemoteImage(url: service.imageUrl)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundCorners(radius: 26, corners: [.topLeft, .topRight]))
            }

            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top, endPoint: .center
            )
            .clipShape(RoundCorners(radius: 26, corners: [.topLeft, .topRight]))

            HStack(alignment: .top) {
                if service.popular {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("POPULAR")
                            .font(AppTheme.sans(10, weight: .bold))
                            .tracking(1.1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.bronzeGradient, in: Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, y: 3)
                }

                Spacer()

                Text("£\(service.priceFrom)")
                    .font(AppTheme.sans(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .padding(14)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(service.name)
                        .font(AppTheme.serif(22))
                        .foregroundColor(AppTheme.ink)

                    Text(service.description)
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.slate)
                        .lineSpacing(3)
                        .lineLimit(isSelected ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }

                Spacer(minLength: 10)

                checkmark
            }

            HStack(spacing: 8) {
                Pill(icon: "clock", text: "\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                Pill(icon: "sparkles", text: "\(service.includes.count) included")

                if !service.hasAvailability {
                    Pill(icon: "exclamationmark.triangle.fill",
                         text: "No availability",
                         fg: AppTheme.warn,
                         bg: AppTheme.warn.opacity(0.12))
                }
            }

            if isSelected && !service.includes.isEmpty {
                includedList
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(18)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isSelected)
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AppTheme.ink : AppTheme.mist)
                .frame(width: 32, height: 32)
            Image(systemName: isSelected ? "checkmark" : "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .white : AppTheme.slate)
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
    }

    private var includedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Included")

            ForEach(service.includes, id: \.self) { item in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(AppTheme.accentSoft).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                    Text(item)
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(AppTheme.ink.opacity(0.85))
                }
            }
        }
        .padding(.top, 4)
    }
}