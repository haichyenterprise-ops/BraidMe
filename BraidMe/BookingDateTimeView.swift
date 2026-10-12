import SwiftUI

// =============================================================================
// BookingDateTimeView — Step 2: pick date and time, upgraded
// Content-transition date pills, period-grouped time chips with spring physics,
// floating glass continue bar.
// =============================================================================

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
                        Color.clear.frame(height: 140)
                    }
                    .padding(.top, Space.md)
                }
            }

            if let slot = selectedSlot {
                continueBar(slot: slot)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
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
        .task {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 2)
                Text("STEP 2 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.gold)
            }

            Text("Pick a time")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            Text(service.name)
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Date strip

    private var dateStrip: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            sectionEyebrow("AVAILABLE DATES")
                .padding(.horizontal, Space.lg)

            if availableDates.isEmpty {
                HStack(spacing: Space.md) {
                    ZStack {
                        Circle()
                            .fill(Color.appSurfaceElevated)
                            .frame(width: 44, height: 44)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.appSmoke)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No dates available")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("This service hasn't been scheduled yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appAsh)
                    }
                    Spacer()
                }
                .padding(Space.md)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .stroke(Color.appDivider, lineWidth: 0.5)
                )
                .padding(.horizontal, Space.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(availableDates, id: \.self) { date in
                            DateStripPill(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                Haptic.select()
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Times

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sectionEyebrow("AVAILABLE TIMES")
                .padding(.horizontal, Space.lg)

            if slotsForDate.isEmpty {
                Text("No times on this date. Try another.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ForEach(groupedSlots, id: \.0) { group in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            HStack(spacing: Space.xs) {
                                Image(systemName: periodIcon(group.0))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.gold)
                                Text(group.0.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.appAsh)
                            }
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 96), spacing: Space.sm)],
                                spacing: Space.sm
                            ) {
                                ForEach(group.1, id: \.self) { label in
                                    TimeChipView(
                                        label: label,
                                        isSelected: selectedSlot == label
                                    ) {
                                        Haptic.select()
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                            selectedSlot = label
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.20), value: appeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Continue bar

    private func continueBar(slot: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.gold.opacity(0.5), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(slot)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.gold)
                }
                Spacer()
                Button {
                    Haptic.press()
                    showPay = true
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Continue")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: 52)
                    .background(Color.appInk, in: Capsule())
                    .shadow(color: Color.appInk.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(BMPressStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Color.glassTintStrong)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Helpers

    private func sectionEyebrow(_ text: String) -> some View {
        HStack(spacing: Space.xs) {
            Rectangle()
                .fill(Color.gold)
                .frame(width: 20, height: 1.5)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.appAsh)
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
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Date Pill
// ═══════════════════════════════════════════════════════════════════

struct DateStripPill: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isSelected ? Color.appInkInverse.opacity(0.7) : Color.appAsh)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(isSelected ? Color.appInkInverse : Color.appInk)
                    .contentTransition(.numericText())
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isSelected ? Color.appInkInverse.opacity(0.7) : Color.appAsh)
            }
            .frame(width: 70, height: 96)
            .background(isSelected ? Color.appInk : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
            )
            .shadow(
                color: isSelected ? Color.appInk.opacity(0.2) : Color.black.opacity(0.04),
                radius: isSelected ? 14 : 6,
                y: isSelected ? 6 : 2
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.96))
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isSelected)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Time Chip
// ═══════════════════════════════════════════════════════════════════

struct TimeChipView: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.appInkInverse : Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(isSelected ? Color.appInk : Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5)
                )
                .shadow(
                    color: isSelected ? Color.appInk.opacity(0.2) : .clear,
                    radius: isSelected ? 12 : 0,
                    y: isSelected ? 4 : 0
                )
        }
        .buttonStyle(BMPressStyle(scale: 0.97))
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isSelected)
    }
}