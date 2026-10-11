import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider
    @State private var styles: [BraidStyle] = []
    @State private var selectedId: String?
    @State private var showPayment = false
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
                            .frame(width: 38, height: 38)
                            .background(AppTheme.snow)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPayment) {
                if let style = selectedStyle {
                    PaymentView(braider: braider, style: style)
                }
            }
            .onAppear { styles = FirebaseManager.shared.braidStyles() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose your style")
                .font(AppTheme.display(30))
                .foregroundColor(AppTheme.ink)
            Text("Select a look from \(braider.name)")
                .font(AppTheme.body(15))
                .foregroundColor(AppTheme.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private var carousel: some View {
        TabView(selection: $selectedId) {
            ForEach(styles) { style in
                StyleCard(style: style, isSelected: selectedId == style.id)
                    .padding(.horizontal, 24)
                    .tag(Optional(style.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 520)
        .onChange(of: selectedId) { _, _ in Haptics.select() }
        .overlay(
            HStack(spacing: 6) {
                ForEach(styles) { style in
                    Capsule()
                        .fill(selectedId == style.id ? AppTheme.ink : AppTheme.hairline)
                        .frame(width: selectedId == style.id ? 22 : 8, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedId)
                }
            }
            .padding(.bottom, 8),
            alignment: .bottom
        )
    }

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            if let style = selectedStyle {
                HStack(spacing: 6) {
                    Text("From")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.stone)
                    Text("£\(style.priceFrom)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text("· \(style.durationMinutes / 60)h \(style.durationMinutes % 60)m")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.slate)
                }
            }

            PrimaryButton(title: "Continue", systemImage: "arrow.right") {
                showPayment = true
            }
            .disabled(selectedStyle == nil)
            .opacity(selectedStyle == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Style Card

struct StyleCard: View {
    let style: BraidStyle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(url: style.imageUrl)
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight]))

                Text("£\(style.priceFrom)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.ink.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(style.name)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.ink)
                    Text(style.description)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.slate)
                        .lineLimit(4)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    infoChip(icon: "clock", text: "\(style.durationMinutes / 60)h \(style.durationMinutes % 60)m")
                    infoChip(icon: "sparkles", text: "\(style.includes.count) included")
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(style.includes, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.accent)
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.ink.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.4), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(AppTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.mist)
        .clipShape(Capsule())
    }
}