import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider
    @State private var styles: [BraidStyle] = []
    @State private var selectedIndex: String? = nil
    @State private var showPayment = false
    @Environment(\.dismiss) var dismiss
    
    private var selectedStyle: BraidStyle? {
        guard let id = selectedIndex else { return nil }
        return styles.first(where: { $0.id == id })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(styles) { style in
                            BraidStyleRow(
                                style: style,
                                isSelected: selectedIndex == style.id,
                                onTap: { handleTap(style) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .background(AppTheme.cloud)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
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
            }
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
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
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        if selectedStyle != nil {
            PrimaryButton(title: "Continue") {
                showPayment = true
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }
    
    private var closeButton: some View {
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
    
    // MARK: - Actions
    
    private func handleTap(_ style: BraidStyle) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            if selectedIndex == style.id {
                selectedIndex = nil
            } else {
                selectedIndex = style.id
            }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

// MARK: - Braid Style Row

struct BraidStyleRow: View {
    let style: BraidStyle
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                styleImage
                if isSelected {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(rowBorder)
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
    
    // MARK: - Subviews (split to help the Swift type-checker)
    
    private var styleImage: some View {
        RemoteImage(url: style.imageUrl)
            .frame(
                width: isSelected ? 100 : 80,
                height: isSelected ? 130 : 100
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isSelected)
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(style.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            
            Text(style.description)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.slate)
                .lineLimit(4)
            
            HStack(spacing: 10) {
                Text("£\(style.priceFrom)+")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                
                Label(durationText, systemImage: "clock")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.slate)
            }
            .padding(.top, 2)
        }
        .padding(.leading, 16)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
    
    private var collapsedContent: some View {
        HStack {
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
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                isSelected ? AppTheme.accent : AppTheme.hairline.opacity(0.6),
                lineWidth: isSelected ? 1.5 : 0.5
            )
    }
    
    private var durationText: String {
        let hours = style.durationMinutes / 60
        let mins = style.durationMinutes % 60
        return "\(hours)h \(mins)m"
    }
}