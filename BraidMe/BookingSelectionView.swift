import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider
    @State private var styles: [BraidStyle] = []
    @State private var selectedIndex: Int? = nil
    @State private var showPayment = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your style")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.ink)
                    Text("Select the look you want from \(braider.name)")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.slate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(styles) { style in
                            BraidStyleRow(
                                style: style,
                                isSelected: selectedIndex == style.id,
                                onTap: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        if selectedIndex == style.id {
                                            selectedIndex = nil
                                        } else {
                                            selectedIndex = style.id
                                        }
                                    }
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .background(AppTheme.cloud)
            .safeAreaInset(edge: .bottom) {
                if let idx = selectedIndex, let style = styles.first(where: { $0.id == idx }) {
                    PrimaryButton(title: "Continue") {
                        showPayment = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.snow)
                            .clipShape(Circle())
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPayment) {
                if let idx = selectedIndex, let style = styles.first(where: { $0.id == idx }) {
                    PaymentView(braider: braider, style: style)
                }
            }
            .onAppear {
                styles = FirebaseManager.shared.braidStyles()
            }
        }
    }
}

struct BraidStyleRow: View {
    let style: BraidStyle
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Image
                RemoteImage(url: style.imageUrl)
                    .frame(width: isSelected ? 100 : 80, height: isSelected ? 130 : 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isSelected)
                
                // Content
                if isSelected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(style.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text(style.description)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.slate)
                            .lineLimit(4)
                        HStack(spacing: 10) {
                            Label("£\(style.priceFrom)+", systemImage: "sterlingsign.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                            Label("\(style.durationMinutes / 60)h \(style.durationMinutes % 60)m", systemImage: "clock")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.slate)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.leading, 16)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(style.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text("From £\(style.priceFrom)")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.slate)
                    }
                    .padding(.leading, 16)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.slate)
                        .padding(.trailing, 16)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.hairline.opacity(0.6),
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
}