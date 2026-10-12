import SwiftUI

struct BookingDateTimeView: View {
    let braider: Braider
    let service: BraidService

    @Environment(\.dismiss) private var dismiss
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
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                BookingProgressHeader(step: 2)
                header
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        dateStrip
                        timesSection
                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, Space.md)
                }
            }

            if let slot = selectedSlot {
                continueBar(slot: slot)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showPay) {
            if let slot = selectedSlot {
                PaymentView(braider: braider, service: service, date: selectedDate, time: slot)
            }
        }
        .task { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Pick a date")
                .font(.bmDisplay(28, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text(service.name)
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.md)
    }

    private var dateStrip: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Available dates")
                .padding(.horizontal, Space.lg)

            if availableDates.isEmpty {
                HStack(spacing: Space.sm) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.bmUI(18))
                        .foregroundStyle(Color.appSmoke)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No dates available")
                            .font(.bmUI(14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("This service hasn't been scheduled yet.")
                            .font(.bmUI(12))
                            .foregroundStyle(Color.appAsh)
                    }
                    Spacer()
                }
                .padding(Space.md)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                .padding(.horizontal, Space.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(availableDates, id: \.self) { date in
                            DateStripPill(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                Haptic.select()
                                withAnimation(Motion.press) {
                                    selectedDate = date
                                    selectedSlot = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionLabel(text: "Available times")
                .padding(.horizontal, Space.lg)

            if slotsForDate.isEmpty {
                Text("No times on this date. Try another.")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ForEach(groupedSlots, id: \.0) { group in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            HStack(spacing: Space.xxs) {
                                Image(systemName: periodIcon(group.0))
                                    .font(.bmUI(11, weight: .semibold))
                                    .foregroundStyle(Color.appAccent)
                                Text(group.0.rawValue.uppercased())
                                    .font(.bmUI(10, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.appAsh)
                            }
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 92), spacing: Space.xs)],
                                spacing: Space.xs
                            ) {
                                ForEach(group.1, id: \.self) { label in
                                    TimeChipView(
                                        label: label,
                                        isSelected: selectedSlot == label
                                    ) {
                                        Haptic.select()
                                        withAnimation(Motion.press) { selectedSlot = label }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    private func continueBar(slot: String) -> some View {
        VStack(spacing: 0) {
            BMDivider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(slot)
                        .font(.bmMono(12, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Button {
                    Haptic.press()
                    showPay = true
                } label: {
                    Text("Continue")
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 48)
                        .background(Color.appInk, in: Capsule())
                }
                .buttonStyle(BMPressStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Color.appSurface)
        }
    }

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
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }
}

// MARK: - Date pill

struct DateStripPill: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.bmUI(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(isSelected ? Color.appInkInverse.opacity(0.75) : Color.appAsh)
                Text(date.formatted(.dateTime.day()))
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appInkInverse : Color.appInk)
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.bmUI(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(isSelected ? Color.appInkInverse.opacity(0.75) : Color.appAsh)
            }
            .frame(width: 64, height: 88)
            .background(isSelected ? Color.appInk : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.96))
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
                .font(.bmMono(13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appInkInverse : Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 4)
                .background(isSelected ? Color.appInk : Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(BMPressStyle(scale: 0.97))
    }
}