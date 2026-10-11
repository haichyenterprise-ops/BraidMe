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

    private var slots: [TimeSlot] { FirebaseManager.shared.timeSlots(for: selectedDate) }

    private var totalPrice: Int {
        style.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    hero
                    optionsCard
                    dateCard
                    timeCard
                    Color.clear.frame(height: 120)
                }
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                payBar
            }
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Booking Confirmed", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text(confirmationMessage)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            RemoteImage(url: style.imageUrl)
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 8)

            VStack(spacing: 4) {
                Text(style.name)
                    .font(AppTheme.display(26))
                    .foregroundColor(AppTheme.ink)
                Text("with \(braider.name)")
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.slate)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Options

    private var optionsCard: some View {
        sectionCard(title: "Add-ons") {
            VStack(spacing: 16) {
                ToggleRow(title: "Hair included", subtitle: "+£30", icon: "scissors", isOn: $includeHair)
                Divider().background(AppTheme.hairline)
                ToggleRow(title: "Add beads", subtitle: "+£15", icon: "circle.grid.hex.fill", isOn: $addBeads)
            }
        }
    }

    // MARK: - Date

    private var dateCard: some View {
        sectionCard(title: "Date") {
            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppTheme.ink)
                .onChange(of: selectedDate) { _, _ in selectedSlot = nil }
        }
    }

    // MARK: - Time

    private var timeCard: some View {
        sectionCard(title: "Time") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(slots) { slot in
                    TimeSlotChip(slot: slot, isSelected: selectedSlot?.id == slot.id) {
                        guard slot.available else { return }
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSlot = slot
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pay Bar

    private var payBar: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.stone)
                    Text("£\(totalPrice)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                        .contentTransition(.numericText())
                }
                Spacer()
                if let slot = selectedSlot {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.stone)
                        Text(slot.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                    }
                }
            }

            Button(action: book) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("Pay with Apple Pay")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppTheme.ink.opacity(0.3), radius: 16, y: 8)
            }
            .buttonStyle(SoftPressStyle())
            .disabled(selectedSlot == nil || isBooking)
            .opacity(selectedSlot == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud, AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Section helper

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.stone)
                .tracking(0.8)
                .padding(.horizontal, 4)
            VStack { content() }
                .padding(16)
                .background(AppTheme.snow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var confirmationMessage: String {
        let d = selectedDate.formatted(date: .long, time: .omitted)
        let t = selectedSlot?.label ?? ""
        return "Your \(style.name.lowercased()) with \(braider.name) is booked for \(d) at \(t)."
    }

    private func book() {
        guard let slot = selectedSlot else { return }
        Haptics.medium()
        isBooking = true
        FirebaseManager.shared.createBooking(
            braiderName: braider.name,
            date: selectedDate,
            time: slot.label,
            style: style.name
        ) { ok in
            isBooking = false
            if ok {
                Haptics.success()
                showConfirmation = true
            } else {
                Haptics.warning()
            }
        }
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.accentDeep)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.ink)
        }
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
                .frame(height: 46)
                .background(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.6), lineWidth: isSelected ? 1.5 : 0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if !slot.available {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.stone)
                            .padding(4)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!slot.available)
    }

    private var bgColor: Color {
        if isSelected { return AppTheme.ink }
        if !slot.available { return AppTheme.mist.opacity(0.6) }
        return AppTheme.snow
    }

    private var textColor: Color {
        if isSelected { return .white }
        if !slot.available { return AppTheme.stone.opacity(0.6) }
        return AppTheme.ink
    }
}