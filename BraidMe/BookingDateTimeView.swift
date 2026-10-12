import SwiftUI

struct BookingDateTimeView: View {
    let braider: Braider
    let service: BraidService

    @Environment(\.dismiss) private var dismiss
    @Namespace private var dateNS
    @State private var selectedDate: Date
    @State private var selectedSlot: String?
    @State private var appeared = false
    @State private var showPay = false

    init(braider: Braider, service: BraidService) {
        self.braider = braider
        self.service = service
        let first = service.availableDates.sorted().first ?? Date()
        _selectedDate = State(initialValue: first)
    }

    private var availableDates: [Date] { service.availableDates.sorted() }

    private var slotsForDate: [String] {
        service.availableSlots[dateKey(selectedDate)] ?? []
    }

    private var groupedSlots: [(DayPeriod, [String])] {
        var m: [String] = [], a: [String] = [], e: [String] = []
        for label in slotsForDate {
            switch periodFor(label) {
            case .morning:   m.append(label)
            case .afternoon: a.append(label)
            case .evening:   e.append(label)
            }
        }
        return [(.morning, m), (.afternoon, a), (.evening, e)].filter { !$0.1.isEmpty }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground(intensity: 0.5)

            VStack(spacing: 0) {
                BookingTopBar(step: 2) { dismiss() }
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        dateStrip
                        timesSection
                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, Space.xs)
                }
            }

            if let slot = selectedSlot {
                continueBar(slot: slot)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showPay) {
            if let slot = selectedSlot {
                PaymentView(braider: braider, service: service, date: selectedDate, time: slot)
            }
        }
        .task { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Pick a time")
                .font(.bmDisplay(36, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Text(service.name)
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .reveal(appeared, offset: 16)
    }

    // MARK: - Dates

    private var dateStrip: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Available dates")
                .padding(.horizontal, Space.lg)

            if availableDates.isEmpty {
                HStack(spacing: Space.sm) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.bmUI(20))
                        .foregroundStyle(LinearGradient.bmGiltGradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No dates available")
                            .font(.bmUI(15, weight: .bold))
                            .foregroundStyle(Color.bmText)
                        Text("This service hasn't been scheduled yet.")
                            .font(.bmUI(13))
                            .foregroundStyle(Color.bmTextDim)
                    }
                    Spacer()
                }
                .padding(Space.md)
                .bmCard(radius: Radius.card)
                .padding(.horizontal, Space.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(Array(availableDates.enumerated()), id: \.element) { index, date in
                            DateStripPill(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                namespace: dateNS
                            ) {
                                Haptic.select()
                                withAnimation(Motion.sheet) {
                                    selectedDate = date
                                    selectedSlot = nil
                                }
                            }
                            .reveal(appeared, delay: Motion.stagger(index) + 0.1, offset: 14, blur: 0)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    // MARK: - Times

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionLabel(text: "Available times")
                .padding(.horizontal, Space.lg)

            if slotsForDate.isEmpty {
                Text("No times on this date. Try another.")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.bmTextDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ForEach(groupedSlots, id: \.0) { group in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            HStack(spacing: 6) {
                                Image(systemName: periodIcon(group.0))
                                    .font(.bmUI(13, weight: .bold))
                                    .foregroundStyle(periodTint(group.0))
                                Text(group.0.rawValue)
                                    .font(.bmUI(14, weight: .bold))
                                    .foregroundStyle(Color.bmText)
                            }
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 96), spacing: Space.xs)],
                                spacing: Space.xs
                            ) {
                                ForEach(group.1, id: \.self) { label in
                                    TimeChipView(
                                        label: label,
                                        isSelected: selectedSlot == label
                                    ) {
                                        Haptic.select()
                                        withAnimation(Motion.sheet) { selectedSlot = label }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.lg)
                .id(dateKey(selectedDate))
                .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
        .animation(Motion.sheet, value: dateKey(selectedDate))
    }

    private func continueBar(slot: String) -> some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.bmUI(14, weight: .bold))
                    .foregroundStyle(Color.bmText)
                Text(slot)
                    .font(.bmNum(13, weight: .bold))
                    .foregroundStyle(Color.bmGilt)
            }
            Spacer(minLength: 0)
            Button {
                Haptic.press()
                showPay = true
            } label: {
                HStack(spacing: Space.xs) {
                    Text("Continue")
                        .font(.bmUI(15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.bmUI(13, weight: .bold))
                }
                .foregroundStyle(Color.bmOnGilt)
                .padding(.horizontal, Space.lg)
                .frame(height: 52)
                .background(LinearGradient.bmGiltGradient, in: Capsule())
            }
            .buttonStyle(BMPressStyle())
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.xs)
        .padding(.vertical, Space.xs)
        .bmGlass(radius: 40, tint: Color.black.opacity(0.3))
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
    }

    // MARK: - Helpers

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private func periodFor(_ label: String) -> DayPeriod {
        let upper = label.uppercased()
        guard let h = upper.split(separator: ":").first, var hour = Int(h) else { return .morning }
        if upper.contains("PM") && hour != 12 { hour += 12 }
        if upper.contains("AM") && hour == 12 { hour = 0 }
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }

    private func periodIcon(_ p: DayPeriod) -> String {
        switch p {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    private func periodTint(_ p: DayPeriod) -> Color {
        switch p {
        case .morning: return Color.bmGilt
        case .afternoon: return Color.bmEmber
        case .evening: return Color.bmOrchid
        }
    }
}

// MARK: - Date pill

struct DateStripPill: View {
    let date: Date
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bmOnGilt.opacity(0.75) : Color.bmTextDim)
                Text(date.formatted(.dateTime.day()))
                    .font(.bmDisplay(26, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bmOnGilt : Color.bmText)
                Text(date.formatted(.dateTime.month(.abbreviated)))
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bmOnGilt.opacity(0.75) : Color.bmTextDim)
            }
            .frame(width: 66, height: 96)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(LinearGradient.bmGiltGradient)
                        .matchedGeometryEffect(id: "datePill", in: namespace)
                        .shadow(color: Color.bmGilt.opacity(0.4), radius: 14, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(Color.bmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                }
            }
        }
        .buttonStyle(BMPressStyle(scale: 0.95))
    }
}

// MARK: - Time chip

struct TimeChipView: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.bmNum(14, weight: .bold))
                .foregroundStyle(isSelected ? Color.bmOnGilt : Color.bmText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(LinearGradient.bmGiltGradient)
                            .shadow(color: Color.bmGilt.opacity(0.35), radius: 10, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(Color.bmSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                    }
                }
        }
        .buttonStyle(BMPressStyle(scale: 0.95))
        .animation(Motion.press, value: isSelected)
    }
}
