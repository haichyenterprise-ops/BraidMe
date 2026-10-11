import SwiftUI
import PassKit

struct PaymentView: View {
    let braider: Braider
    let style: BraidStyle

    // MARK: - State
    @State private var selectedDate = Date()
    @State private var selectedSlot: TimeSlot?
    @State private var includeHair = true
    @State private var addBeads = false
    @State private var useApplePay = true
    @State private var showConfirmation = false
    @State private var isBooking = false
    @State private var applePayController: PKPaymentAuthorizationController?
    @State private var appeared = false
    @Environment(\.dismiss) var dismiss

    // MARK: - Computed
    private var slots: [TimeSlot] { FirebaseManager.shared.timeSlots(for: selectedDate) }

    private var morningSlots: [TimeSlot] { slots.filter { $0.period == .morning } }
    private var afternoonSlots: [TimeSlot] { slots.filter { $0.period == .afternoon } }
    private var eveningSlots: [TimeSlot] { slots.filter { $0.period == .evening } }

    private var totalPrice: Int {
        style.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }

    private var canPay: Bool {
        selectedSlot != nil && !isBooking
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.cloud.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    hero
                    optionsCard
                    dateCard
                    timeCard
                    reviewNote
                    Color.clear.frame(height: 180)
                }
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            payBar
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Booking Confirmed", isPresented: $showConfirmation) {
            Button("Done") {
                Haptics.success()
                dismiss()
            }
        } message: {
            Text(confirmationMessage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.bronzeSoft)
                    .frame(width: 156, height: 156)

                RemoteImage(url: style.imageUrl)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 10)

                if style.popular {
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
                    .offset(y: 66)
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 10, y: 4)
                }
            }

            VStack(spacing: 6) {
                Text(style.name)
                    .font(AppTheme.serif(28))
                    .foregroundColor(AppTheme.ink)

                HStack(spacing: 6) {
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
        }
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Options card

    private var optionsCard: some View {
        SectionCard(title: "Add-ons", icon: "plus.circle") {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "Hair included",
                    subtitle: "Premium braiding hair",
                    price: 30,
                    icon: "scissors",
                    isOn: $includeHair
                )

                Divider().background(AppTheme.hairline).padding(.leading, 54)

                ToggleRow(
                    title: "Add beads",
                    subtitle: "Gold, silver, or wood",
                    price: 15,
                    icon: "circle.grid.hex.fill",
                    isOn: $addBeads
                )
            }
        }
    }

    // MARK: - Date card

    private var dateCard: some View {
        SectionCard(title: "Pick a date", icon: "calendar") {
            VStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppTheme.ink)

                if let weekday = selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)).split(separator: " ").first {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.accent)
                        Text("Selected: \(String(weekday)) \(selectedDate.formatted(.dateTime.day().month(.wide)))")
                            .font(AppTheme.sans(12, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                    }
                }
            }
        }
        .onChange(of: selectedDate) { _, _ in
            withAnimation { selectedSlot = nil }
            Haptics.select()
        }
    }

    // MARK: - Time card

    private var timeCard: some View {
        SectionCard(title: "Choose a time", icon: "clock") {
            VStack(alignment: .leading, spacing: 18) {
                if !morningSlots.isEmpty {
                    timeGroup(label: "Morning", slots: morningSlots, icon: "sunrise.fill")
                }
                if !afternoonSlots.isEmpty {
                    timeGroup(label: "Afternoon", slots: afternoonSlots, icon: "sun.max.fill")
                }
                if !eveningSlots.isEmpty {
                    timeGroup(label: "Evening", slots: eveningSlots, icon: "moon.stars.fill")
                }
            }
        }
    }

    private func timeGroup(label: String, slots: [TimeSlot], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(label.uppercased())
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.stone)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                spacing: 10
            ) {
                ForEach(slots) { slot in
                    TimeSlotChip(
                        slot: slot,
                        isSelected: selectedSlot?.id == slot.id
                    ) {
                        guard slot.available else {
                            Haptics.warning()
                            return
                        }
                        Haptics.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedSlot = slot
                        }
                    }
                }
            }
        }
    }

    // MARK: - Review note

    private var reviewNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Secure booking")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Free cancellation up to 24 hours before your appointment. Payment processed securely via Apple Pay.")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(AppTheme.accentSoft.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Pay Bar (sticky)

    private var payBar: some View {
        VStack(spacing: 14) {
            // Summary row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOTAL")
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(AppTheme.stone)

                    Text("£\(totalPrice)")
                        .font(AppTheme.serif(30))
                        .foregroundColor(AppTheme.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: totalPrice)
                }

                Spacer()

                if let slot = selectedSlot {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(AppTheme.sans(12, weight: .medium))
                            .foregroundColor(AppTheme.stone)
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.accent)
                            Text(slot.label)
                                .font(AppTheme.sans(14, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    Text("Select a time")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(AppTheme.stone)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSlot)

            // Pay button
            Button(action: startPayment) {
                HStack(spacing: 8) {
                    if isBooking {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "applelogo")
                        Text("Pay")
                            .font(AppTheme.sans(17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: AppTheme.ink.opacity(0.32), radius: 20, y: 10)
            }
            .buttonStyle(SoftPress())
            .disabled(!canPay)
            .opacity(canPay ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.cloud.opacity(0),
                    AppTheme.cloud.opacity(0.95),
                    AppTheme.cloud
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Payment

    private func startPayment() {
        guard let slot = selectedSlot else { return }
        Haptics.medium()

        // Simulated flow — the actual Apple Pay sheet requires a signed build
        // with a PassKit merchant ID. This fallback ensures the demo still completes.
        isBooking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            FirebaseManager.shared.createBooking(
                braider: braider,
                date: selectedDate,
                time: slot.label,
                style: style,
                price: totalPrice
            ) { ok in
                isBooking = false
                if ok {
                    Haptics.success()
                    showConfirmation = true
                } else {
                    Haptics.error()
                }
            }
        }
    }

    // MARK: - Apple Pay availability (real implementation, activated when signed)

    private func presentApplePaySheet() {
        guard let slot = selectedSlot else { return }

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.example.BraidMe"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "GB"
        request.currencyCode = "GBP"

        let total = PKPaymentSummaryItem(
            label: "BraidMe · \(style.name)",
            amount: NSDecimalNumber(value: totalPrice)
        )
        let braider = PKPaymentSummaryItem(
            label: self.braider.name,
            amount: NSDecimalNumber(value: totalPrice - 30)
        )
        let hair = PKPaymentSummaryItem(
            label: "Hair included",
            amount: NSDecimalNumber(value: 30)
        )
        request.paymentSummaryItems = [braider, hair, total]

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = ApplePayDelegate.shared
        ApplePayDelegate.shared.onSuccess = {
            FirebaseManager.shared.createBooking(
                braider: self.braider,
                date: self.selectedDate,
                time: slot.label,
                style: self.style,
                price: self.totalPrice
            ) { ok in
                DispatchQueue.main.async {
                    if ok {
                        Haptics.success()
                        self.showConfirmation = true
                    }
                }
            }
        }
        self.applePayController = controller
        controller.present { _ in }
    }

    // MARK: - Confirmation text

    private var confirmationMessage: String {
        let d = selectedDate.formatted(date: .long, time: .omitted)
        let t = selectedSlot?.label ?? ""
        return "Your \(style.name.lowercased()) with \(braider.name) is booked for \(d) at \(t). Confirmation sent to your device."
    }
}

// MARK: - Apple Pay Delegate

final class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
    static let shared = ApplePayDelegate()
    var onSuccess: (() -> Void)?

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        onSuccess?()
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft)
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }

                Text(title.uppercased())
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(AppTheme.stone)
            }
            .padding(.horizontal, 4)

            VStack {
                content()
            }
            .padding(16)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let price: Int
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isOn ? AppTheme.accentSoft : AppTheme.mist)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isOn ? AppTheme.accent : AppTheme.stone)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOn)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.stone)
                    Text("+£\(price)")
                        .font(AppTheme.sans(11, weight: .bold))
                        .foregroundColor(AppTheme.accentDeep)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentSoft, in: Capsule())
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.ink)
                .onChange(of: isOn) { _, _ in Haptics.select() }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Time Slot Chip

struct TimeSlotChip: View {
    let slot: TimeSlot
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Text(slot.label)
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if !slot.available {
                    Rectangle()
                        .fill(AppTheme.stone.opacity(0.4))
                        .frame(height: 1)
                        .rotationEffect(.degrees(-12))
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.6),
                        lineWidth: isSelected ? 1.5 : 0.7
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(SoftPress())
        .disabled(!slot.available)
    }

    private var bgColor: Color {
        if isSelected { return AppTheme.ink }
        if !slot.available { return AppTheme.mist.opacity(0.55) }
        return AppTheme.snow
    }

    private var textColor: Color {
        if isSelected { return .white }
        if !slot.available { return AppTheme.stone.opacity(0.55) }
        return AppTheme.ink
    }
}