import SwiftUI

struct PaymentView: View {
    let braider: Braider
    let style: BraidStyle
    
    @State private var selectedDate = Date()
    @State private var selectedSlot: TimeSlot?
    @State private var includeHair = true
    @State private var addBeads = false
    @State private var showConfirmation = false
    @State private var isBooking = false
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Computed
    
    private var slots: [TimeSlot] {
        FirebaseManager.shared.timeSlots(for: selectedDate)
    }
    
    private var totalPrice: Int {
        style.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }
    
    private var canBook: Bool {
        selectedSlot != nil && !isBooking
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                optionsCard
                dateCard
                timeSlotCard
                totalAndPaySection
            }
        }
        .background(AppTheme.cloud)
        .navigationTitle("Confirm Booking")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Booking Confirmed", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: 14) {
            RemoteImage(url: style.imageUrl)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            
            VStack(spacing: 4) {
                Text(style.name)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.ink)
                Text("with \(braider.name)")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.slate)
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Options Card
    
    private var optionsCard: some View {
        sectionCard(title: "Options") {
            VStack(spacing: 14) {
                ToggleRow(title: "Hair included", subtitle: "+£30", isOn: $includeHair)
                
                Divider().background(AppTheme.hairline)
                
                ToggleRow(title: "Add beads", subtitle: "+£15", isOn: $addBeads)
            }
        }
    }
    
    // MARK: - Date Card
    
    private var dateCard: some View {
        sectionCard(title: "Choose a date") {
            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppTheme.ink)
                .onChange(of: selectedDate) { _, _ in
                    selectedSlot = nil
                }
        }
    }
    
    // MARK: - Time Slot Card
    
    private var timeSlotCard: some View {
        sectionCard(title: "Choose a time") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 10)],
                spacing: 10
            ) {
                ForEach(slots) { slot in
                    TimeSlotChip(
                        slot: slot,
                        isSelected: selectedSlot?.id == slot.id,
                        onTap: { handleSlotTap(slot) }
                    )
                }
            }
        }
    }
    
    // MARK: - Total & Pay
    
    private var totalAndPaySection: some View {
        VStack(spacing: 14) {
            totalRow
            payButton
            if selectedSlot == nil {
                helperText
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    private var totalRow: some View {
        HStack {
            Text("Total")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.slate)
            Spacer()
            Text("£\(totalPrice)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppTheme.ink)
        }
    }
    
    private var payButton: some View {
        Button(action: book) {
            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                Text("Pay")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!canBook)
        .opacity(selectedSlot == nil ? 0.45 : 1)
    }
    
    private var helperText: some View {
        Text("Please select a time slot to continue")
            .font(.system(size: 12))
            .foregroundColor(AppTheme.slate)
    }
    
    // MARK: - Section Card Wrapper
    
    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.slate)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            
            VStack {
                content()
            }
            .padding(16)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private var confirmationMessage: String {
        let dateStr = selectedDate.formatted(date: .long, time: .omitted)
        let timeStr = selectedSlot?.label ?? ""
        return "Your \(style.name.lowercased()) with \(braider.name) is booked for \(dateStr) at \(timeStr)."
    }
    
    private func handleSlotTap(_ slot: TimeSlot) {
        guard slot.available else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedSlot = slot
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    private func book() {
        guard let slot = selectedSlot else { return }
        isBooking = true
        FirebaseManager.shared.createBooking(
            braiderName: braider.name,
            date: selectedDate,
            time: slot.label,
            style: style.name
        ) { success in
            isBooking = false
            if success {
                showConfirmation = true
            }
        }
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.slate)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.ink)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Time Slot Chip

struct TimeSlotChip: View {
    let slot: TimeSlot
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(slot.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!slot.available)
    }
    
    private var bgColor: Color {
        if isSelected { return AppTheme.ink }
        if !slot.available { return AppTheme.mist }
        return AppTheme.snow
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if !slot.available { return AppTheme.slate.opacity(0.5) }
        return AppTheme.ink
    }
    
    private var borderColor: Color {
        if isSelected { return AppTheme.ink }
        return AppTheme.hairline.opacity(0.7)
    }
}