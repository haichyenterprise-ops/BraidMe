import SwiftUI

struct PaymentView: View {
    let braider: Braider
    let service: BraidService

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var selectedDate: Date
    @State private var selectedSlot: String?
    @State private var includeHair = true
    @State private var addBeads = false
    @State private var showConfirmation = false
    @State private var isBooking = false
    @State private var appeared = false

    init(braider: Braider, service: BraidService) {
        self.braider = braider
        self.service = service
        let firstDate = service.availableDates.sorted().first ?? Date()
        _selectedDate = State(initialValue: firstDate)
    }

    // MARK: - Computed

    private var availableDatesSorted: [Date] { service.availableDates.sorted() }

    private var slotsForSelectedDate: [String] {
        service.availableSlots[Self.dateKey(selectedDate)] ?? []
    }

    private var groupedSlots: [(DayPeriod, [String])] {
        var morning: [String] = []
        var afternoon: [String] = []
        var evening: [String] = []

        for label in slotsForSelectedDate {
            switch Self.periodFor(label) {
            case .morning:   morning.append(label)
            case .afternoon: afternoon.append(label)
            case .evening:   evening.append(label)
            }
        }
        return [(.morning, morning), (.afternoon, afternoon), (.evening, evening)]
            .filter { !$0.1.isEmpty }
    }

    private var totalPrice: Int {
        service.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }

    private var canPay: Bool {
        selectedSlot != nil && !isBooking
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.cloud.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    optionsCard
                    datesCard
                    slotsCard
                    reviewNote
                    Color.clear.frame(height: 180)
                }
                .padding(.bottom, 20)
            }

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

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.bronzeSoft).frame(width: 156, height: 156)
                if service.imageUrl.isEmpty {
                    ZStack {
                        Circle().fill(AppTheme.mist).frame(width: 140, height: 140)
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.ash)
                    }
                } else {
                    RemoteImage(url: service.imageUrl)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                }
            }

            VStack(spacing: 6) {
                Text(service.name)
                    .font(AppTheme.serif(28))
                    .foregroundColor(AppTheme.ink)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Text("with")
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.stone)
                    Text(braider.name)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
        }
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var optionsCard: some View {
        PaymentSectionCard(title: "Add-ons", icon: "plus.circle") {
            VStack(spacing: 0) {
                PaymentToggleRow(title: "Hair included",
                                 subtitle: "Premium braiding hair",
                                 price: 30,
                                 icon: "scissors",
                                 isOn: $includeHair)
                Divider().background(AppTheme.hairline).padding(.leading, 54)
                PaymentToggleRow(title: "Add beads",
                                 subtitle: "Gold, silver, or wood",
                                 price: 15,
                                 icon: "circle.grid.hex.fill",
                                 isOn: $addBeads)
            }
        }
    }

    private var datesCard: some View {
        PaymentSectionCard(title: "Available dates", icon: "calendar") {
            if availableDatesSorted.isEmpty {
                emptyDates
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableDatesSorted, id: \.self) { date in
                            DateChip(date: date,
                                     isSelected: Self.sameDay(date, selectedDate)) {
                                Haptics.select()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedDate = date
                                    selectedSlot = nil
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyDates: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.stone)
            VStack(alignment: .leading, spacing: 2) {
                Text("No dates available")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("This service hasn't been scheduled yet.")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.stone)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var slotsCard: some View {
        PaymentSectionCard(title: "Available times", icon: "clock") {
            if slotsForSelectedDate.isEmpty {
                emptySlots
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedSlots, id: \.0) { group in
                        SlotGroup(period: group.0,
                                  slots: group.1,
                                  selectedSlot: $selectedSlot)
                    }
                }
            }
        }
    }

    private var emptySlots: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.stone)
            VStack(alignment: .leading, spacing: 2) {
                Text("No times on this date")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Try a different date above.")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.stone)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var reviewNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Secure booking")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Free cancellation up to 24 hours before.")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(AppTheme.accentSoft.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var payBar: some View {
        VStack(spacing: 14) {
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
                            Text(slot)
                                .font(AppTheme.sans(14, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                        }
                    }
                } else {
                    Text("Select a time")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(AppTheme.stone)
                }
            }

            Button(action: book) {
                HStack(spacing: 8) {
                    if isBooking {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "applelogo")
                        Text("Confirm & Pay")
                            .font(AppTheme.sans(17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
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
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud.opacity(0.95), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func book() {
        guard let slot = selectedSlot else { return }
        let uid = session.uid
        guard !uid.isEmpty else {
            Haptics.error()
            return
        }

        Haptics.medium()
        isBooking = true

        FirebaseManager.shared.createBooking(
            braider: braider,
            date: selectedDate,
            time: slot,
            service: service,
            price: totalPrice,
            uid: uid
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

    private var confirmationMessage: String {
        let d = selectedDate.formatted(date: .long, time: .omitted)
        let t = selectedSlot ?? ""
        return "Your \(service.name.lowercased()) with \(braider.name) is booked for \(d) at \(t)."
    }

    static func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    static func periodFor(_ label: String) -> DayPeriod {
        let upper = label.uppercased()
        guard let hourPart = upper.split(separator: ":").first,
              var hour = Int(hourPart) else { return .morning }
        if upper.contains("PM") && hour != 12 { hour += 12 }
        if upper.contains("AM") && hour == 12 { hour = 0 }
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }
}

// MARK: - Section card

struct PaymentSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(AppTheme.accentSoft).frame(width: 26, height: 26)
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

            VStack { content() }
                .padding(16)
                .background(AppTheme.snow)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
        }
        .padding(.horizontal, 20)
    }
}

struct PaymentToggleRow: View {
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
        }
        .padding(.vertical, 6)
    }
}

struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    private var weekday: String { date.formatted(.dateTime.weekday(.abbreviated)).uppercased() }
    private var day: String { date.formatted(.dateTime.day()) }
    private var month: String { date.formatted(.dateTime.month(.abbreviated)).uppercased() }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(weekday)
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(isSelected ? .white.opacity(0.75) : AppTheme.stone)
                Text(day)
                    .font(AppTheme.serif(22))
                    .foregroundColor(isSelected ? .white : AppTheme.ink)
                Text(month)
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(isSelected ? .white.opacity(0.75) : AppTheme.stone)
            }
            .frame(width: 62, height: 84)
            .background(isSelected ? AppTheme.ink : AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : AppTheme.hairline.opacity(0.6), lineWidth: 0.7)
            )
            .shadow(color: isSelected ? AppTheme.ink.opacity(0.25) : .black.opacity(0.03),
                    radius: isSelected ? 12 : 4, y: isSelected ? 6 : 2)
        }
        .buttonStyle(SoftPress())
    }
}

struct SlotGroup: View {
    let period: DayPeriod
    let slots: [String]
    @Binding var selectedSlot: String?

    private var icon: String {
        switch period {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(period.rawValue.uppercased())
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.stone)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(slots, id: \.self) { label in
                    TimeChip(label: label, isSelected: selectedSlot == label) {
                        Haptics.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedSlot = label
                        }
                    }
                }
            }
        }
    }
}

struct TimeChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(AppTheme.sans(14, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isSelected ? AppTheme.ink : AppTheme.snow)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.ink : AppTheme.hairline.opacity(0.6),
                                lineWidth: isSelected ? 1.5 : 0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(SoftPress())
    }
}