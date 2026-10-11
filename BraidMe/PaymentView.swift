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
    
    private var slots: [TimeSlot] {
        FirebaseManager.shared.timeSlots(for: selectedDate)
    }
    
    private var totalPrice: Int {
        style.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero
                VStack(spacing: 14) {
                    RemoteImage(url: style.imageUrl)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                    Text(style.name)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.ink)
                    Text("with \(braider.name)")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.slate)
                }
                .padding(.top, 10)
                
                // Options
                sectionCard(title: "Options") {
                    ToggleRow(title: "Hair included", subtitle: "+£30", isOn: $includeHair)
                    Divider().background(AppTheme.hairline)
                    ToggleRow(title: "Add beads", subtitle: "+£15", isOn: $addBeads)
                }
                
                // Date picker
                sectionCard(title: "Choose a date") {
                    DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.ink)
                        .onChange(of: selectedDate) { _, _ in
                            selectedSlot = nil
                        }
                }
                
                // Time slots
                sectionCard(title: "Choose a time") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                        ForEach(slots) { slot in
                            TimeSlotChip(
                                slot: slot,
                                isSelected: selectedSlot?.id == slot.id,
                                onTap: {
                                    guard slot.available else { return }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedSlot = slot
                                    }
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            )
                        }
                    }
                }
                
                // Total + Apple Pay
                VStack(spacing: 14) {
                    HStack {
                        Text("Total")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                        Spacer()
                        Text("£\(totalPrice)")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.ink)
                    }
                    
                    Button(action: { book() }) {
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
                    .disabled(selectedSlot == nil || isBooking)
                    .opacity(selectedSlot == nil ? 0.45 : 1)
                    
                    if selectedSlot == nil {
                        Text("Please select a time slot to continue")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.slate)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(AppTheme.cloud)
        .navigationTitle("Confirm Booking")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Booking Confirmed", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your \(style.name.lowercased()) with \(braider.name) is booked for \(selectedDate.formatted(date: .long, time: .omitted)) at \(selectedSlot?.label ?? "").")
        }
    }
    
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.slate)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            VStack { content() }
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
            if success { showConfirmation = true }
        }
    }
}

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
                        .stroke(isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.7),
                                lineWidth: isSelected ? 1.5 : 0.7)
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
}