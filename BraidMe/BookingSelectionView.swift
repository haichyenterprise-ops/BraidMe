import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider

    @State private var styles: [BraidStyle] = []
    @State private var selectedId: String?
    @State private var showPayment = false
    @State private var appeared = false
    @Environment(\.dismiss) var dismiss

    private var selectedStyle: BraidStyle? {
        guard let id = selectedId else { return nil }
        return styles.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    carousel
                    Spacer(minLength: 0)
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
                    }
                    .buttonStyle(BouncyPress())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPayment) {
                if let style = selectedStyle {
                    PaymentView(braider: braider, style: style)
                }
            }
            .onAppear {
                styles = FirebaseManager.shared.braidStyles()
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick your style")
                .font(AppTheme.serif(34))
                .foregroundColor(AppTheme.ink)

            HStack(spacing: 8) {
                Text("with")
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.stone)
                Text(braider.name)
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Carousel

    private var carousel: some View {
        TabView(selection: $selectedId) {
            ForEach(styles) { style in
                StyleCard(style: style, isSelected: selectedId == style.id)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .tag(Optional(style.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 540)
        .onChange(of: selectedId) { _, _ in Haptics.select() }
        .overlay(alignment: .bottom) {
            progressDots
        }
        .opacity(appeared ? 1 : 0)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(styles) { style in
                Capsule()
                    .fill(selectedId == style.id ? AppTheme.ink : AppTheme.hairline)
                    .frame(
                        width: selectedId == style.id ? 24 : 8,
                        height: 6
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedId)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if let style = selectedStyle {
                HStack(spacing: 8) {
                    Text("From")
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.stone)
                    Text("£\(style.priceFrom)")
                        .font(AppTheme.serif(20))
                        .foregroundColor(AppTheme.ink)
                    Text("·")
                        .foregroundColor(AppTheme.stone)
                    Text("\(style.durationMinutes / 60)h \(style.durationMinutes % 60)m")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            PrimaryButton(title: "Continue", icon: "arrow.right") {
                showPayment = true
            }
            .disabled(selectedStyle == nil)
            .opacity(selectedStyle == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedId)
    }
}

// MARK: - Style card

struct StyleCard: View {
    let style: BraidStyle
    let isSelected: Bool

    var body: some View {
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
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 24 : 14, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }

    private var imageBlock: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImage(url: style.imageUrl)
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .clipShape(RoundCorners(radius: 26, corners: [.topLeft, .topRight]))

            // Price pill
            Text("£\(style.priceFrom)")
                .font(AppTheme.sans(14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.ink.opacity(0.85), in: Capsule())
                .padding(14)

            // Popular badge
            if style.popular {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("POPULAR")
                            .font(AppTheme.sans(10, weight: .bold))
                            .tracking(1.0)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.bronzeGradient, in: Capsule())
                    .padding(14)

                    Spacer()
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(style.name)
                    .font(AppTheme.serif(26))
                    .foregroundColor(AppTheme.ink)

                Text(style.description)
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .lineLimit(3)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                infoPill(icon: "clock", text: "\(style.durationMinutes / 60)h \(style.durationMinutes % 60)m")
                infoPill(icon: "sparkles", text: "\(style.includes.count) included")
            }

            includedList
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var includedList: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "Included")
                .padding(.bottom, 2)

            ForEach(style.includes, id: \.self) { item in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentSoft)
                            .frame(width: 22, height: 22)
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

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(AppTheme.sans(12, weight: .medium))
        }
        .foregroundColor(AppTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.mist, in: Capsule())
    }
}