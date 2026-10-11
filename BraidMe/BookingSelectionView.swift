import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @State private var selectedId: String?
    @State private var showPayment = false
    @State private var appeared = false

    private var styles: [BraidStyle] { braider.styles }

    private var selectedStyle: BraidStyle? {
        guard let id = selectedId else { return nil }
        return styles.first(where: { $0.id == id })
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
                            .padding(.bottom, 20)

                        LazyVStack(spacing: 26) {
                            ForEach(styles) { style in
                                CarouselCard(
                                    style: style,
                                    isSelected: selectedId == style.id,
                                    onTap: { toggleSelect(style) }
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 180)
                    }
                }

                VStack {
                    Spacer()
                    bottomCTA
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    IconButton(
                        icon: "xmark",
                        size: 40,
                        iconSize: 15,
                        fg: AppTheme.ink,
                        bg: AppTheme.snow
                    ) {
                        dismiss()
                    }
                    .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.5))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPayment) {
                if let style = selectedStyle {
                    PaymentView(braider: braider, style: style)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                Text("SELECT A STYLE")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("What are you\nlooking for?")
                .font(AppTheme.serif(34))
                .lineSpacing(-2)
                .foregroundColor(AppTheme.ink)

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

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if let style = selectedStyle {
                HStack(spacing: 10) {
                    Text("Selected")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.stone)
                    Text(style.name)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Spacer()
                    Text("£\(style.priceFrom)")
                        .font(AppTheme.serif(18))
                        .foregroundColor(AppTheme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.mist)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            PrimaryButton(title: "Continue", icon: "arrow.right") {
                showPayment = true
            }
            .disabled(selectedStyle == nil)
            .opacity(selectedStyle == nil ? 0.4 : 1)
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

    private func toggleSelect(_ style: BraidStyle) {
        Haptics.select()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            if selectedId == style.id {
                selectedId = nil
            } else {
                selectedId = style.id
            }
        }
    }
}

// MARK: - Carousel card

struct CarouselCard: View {
    let style: BraidStyle
    let isSelected: Bool
    let onTap: () -> Void

    // Portably animate scale/opacity based on where the card sits in the viewport.
    private let cardHeight: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let screenMid = UIScreen.main.bounds.height / 2
            let cardMid = frame.midY
            let distance = abs(screenMid - cardMid) / screenMid
            let clamped = min(max(distance, 0), 1)
            let scale = 1 - clamped * 0.08
            let opacity = 1 - clamped * 0.35

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
                .scaleEffect(scale)
                .opacity(opacity)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: scale)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
            }
            .buttonStyle(CardPress())
        }
        .frame(height: cardHeight)
    }

    // MARK: - Image

    private var imageBlock: some View {
        ZStack(alignment: .topLeading) {
            RemoteImage(url: style.imageUrl)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundCorners(radius: 26, corners: [.topLeft, .topRight]))

            LinearGradient(
                colors: [.black.opacity(0.35), .clear],
                startPoint: .top, endPoint: .center
            )
            .clipShape(RoundCorners(radius: 26, corners: [.topLeft, .topRight]))

            HStack(alignment: .top) {
                if style.popular {
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
                } else {
                    Color.clear.frame(width: 0, height: 0)
                }

                Spacer()

                Text("£\(style.priceFrom)")
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

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(style.name)
                        .font(AppTheme.serif(22))
                        .foregroundColor(AppTheme.ink)

                    Text(style.description)
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.slate)
                        .lineSpacing(3)
                        .lineLimit(isSelected ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                checkmark
            }

            HStack(spacing: 8) {
                Pill(icon: "clock", text: "\(style.durationMinutes / 60)h \(style.durationMinutes % 60)m")
                Pill(icon: "sparkles", text: "\(style.includes.count) included")
            }

            if isSelected {
                includedList
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(18)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isSelected)
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AppTheme.ink : AppTheme.mist)
                .frame(width: 30, height: 30)
            Image(systemName: isSelected ? "checkmark" : "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .white : AppTheme.slate)
        }
        .scaleEffect(isSelected ? 1.05 : 1)
    }

    private var includedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Included")

            ForEach(style.includes, id: \.self) { item in
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