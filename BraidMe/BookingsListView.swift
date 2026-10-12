import SwiftUI

struct BookingsListView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var filter: Filter = .current
    @State private var activeChat: Booking?
    @State private var cancelBooking: Booking?
    @State private var appeared = false
    @State private var loading = false

    enum Filter: String, CaseIterable {
        case current = "Upcoming"
        case past = "History"
    }

    private var filtered: [Booking] {
        let now = Calendar.current.startOfDay(for: Date())
        return fb.bookings.filter { b in
            let isPast = b.date < now || b.status == "completed" || b.status == "cancelled"
            return filter == .current ? !isPast : isPast
        }
        .sorted { filter == .current ? $0.date < $1.date : $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Ambient gradient
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 350
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    filterTabs
                    content
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BMGlassIconButton(icon: "xmark", size: 40, iconSize: 14, tint: .appInk) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $activeChat) { booking in
                ChatView(booking: booking, currentUserId: session.uid)
            }
            .sheet(item: $cancelBooking) { booking in
                CancelBookingSheet(booking: booking) { cancelBooking = nil }
            }
            .task {
                let uid = session.uid
                guard !uid.isEmpty else { return }
                loading = true
                await fb.loadBookings(uid: uid)
                loading = false
                withAnimation(Motion.heroReveal.delay(0.1)) { appeared = true }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 20, height: 2)
                Text("YOUR APPOINTMENTS")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAccent)
            }

            Text("My bookings")
                .font(.bmHero(34))
                .foregroundStyle(Color.appInk)
                .lineSpacing(-4)

            Text(verbatim: "\(fb.bookings.count) appointment\(fb.bookings.count == 1 ? "" : "s")")
                .font(.bmUI(14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animate(Motion.heroReveal, value: appeared)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptic.select()
                    withAnimation(Motion.bouncy) { filter = f }
                } label: {
                    VStack(spacing: 8) {
                        Text(f.rawValue)
                            .font(.bmUI(14, weight: .semibold))
                            .foregroundStyle(filter == f ? Color.appInk : Color.appAsh)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(filter == f ? Color.appAccent : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if loading && fb.bookings.isEmpty {
            BMLoadingView(message: "Loading your bookings")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            emptyState
        } else {
            listView
        }
    }

    private var emptyState: some View {
        BMEmptyState(
            icon: filter == .current ? "calendar.badge.plus" : "clock.arrow.circlepath",
            title: filter == .current ? "No upcoming bookings" : "No history yet",
            message: filter == .current
                ? "Book a braider from the map to get started."
                : "Your completed appointments will appear here."
        )
        .frame(maxHeight: .infinity)
    }

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Space.md) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, booking in
                    BookingCardView(
                        booking: booking,
                        isPast: filter == .past,
                        onMessage: {
                            Haptic.select()
                            activeChat = booking
                        },
                        onCancel: {
                            Haptic.warning()
                            cancelBooking = booking
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
                }
                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.lg)
        }
        .refreshable {
            await fb.loadBookings(uid: session.uid)
        }
    }
}

// MARK: - Booking Card

struct BookingCardView: View {
    let booking: Booking
    let isPast: Bool
    let onMessage: () -> Void
    let onCancel: () -> Void

    private var canMessage: Bool {
        booking.status == "confirmed" || booking.status == "cancellation_requested"
    }
    private var canCancel: Bool {
        booking.status == "confirmed" && booking.date > Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.md) {
                dateBadge

                VStack(alignment: .leading, spacing: 6) {
                    Text(booking.style)
                        .font(.bmDisplay(19, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "scissors")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appSmoke)
                        Text(booking.braiderName)
                            .font(.bmUI(13, weight: .medium))
                            .foregroundStyle(Color.appAsh)
                    }

                    HStack(spacing: Space.xs) {
                        Text("£\(booking.price)")
                            .font(.bmMono(15, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text(booking.time)
                            .font(.bmUI(13))
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                statusBadge
            }

            if !isPast && (canMessage || canCancel) {
                HStack(spacing: Space.sm) {
                    if canMessage {
                        Button(action: onMessage) {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.bmUI(11, weight: .semibold))
                                Text("Message")
                                    .font(.bmUI(13, weight: .semibold))
                            }
                            .foregroundStyle(Color.appInkInverse)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(Color.appInk, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.appInk.opacity(0.15), radius: 8, y: 4)
                        }
                        .buttonStyle(BMPressStyle())
                    }
                    if canCancel {
                        Button(action: onCancel) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.bmUI(11, weight: .semibold))
                                Text("Cancel")
                                    .font(.bmUI(13, weight: .semibold))
                            }
                            .foregroundStyle(Color.appAlert)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(Color.appAlert.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appAlert.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(BMPressStyle())
                    }
                }
            }
        }
        .padding(Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .shadow(color: Color.appInk.opacity(0.06), radius: 16, y: 8)
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.bmUI(9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.appInkInverse.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(.bmDisplay(22, weight: .semibold))
                .foregroundStyle(Color.appInkInverse)
        }
        .frame(width: 56, height: 64)
        .background(monthColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: monthColor.opacity(0.3), radius: 8, y: 4)
    }

    private var monthColor: Color {
        if booking.status == "cancelled" || booking.status == "cancellation_denied" { return Color.appSmoke }
        if booking.date < Calendar.current.startOfDay(for: Date()) { return Color.appSmoke }
        if Calendar.current.isDateInToday(booking.date) { return Color.appAccent }
        return Color.appInk
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", Color.appSignal)
            case "completed": return ("Completed", Color.appAsh)
            case "cancelled": return ("Cancelled", Color.appAlert)
            case "cancellation_requested": return ("Pending", Color.appAccent)
            case "cancellation_denied": return ("Denied", Color.appAlert)
            default: return (booking.status.capitalized, Color.appAsh)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.bmUI(10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Cancel Booking Sheet

struct CancelBookingSheet: View {
    let booking: Booking
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var reason = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                RadialGradient(
                    colors: [Color.appAlert.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 350
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.lg) {
                        iconHeader
                        reasonBlock
                        submitButton
                    }
                    .padding(Space.lg)
                }
            }
            .navigationTitle("Cancel booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                        onDismiss()
                    }
                    .font(.bmUI(15, weight: .medium))
                    .foregroundStyle(Color.appAsh)
                }
            }
            .alert("Request sent", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text("Your cancellation request has been sent to \(booking.braiderName). They'll respond shortly.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            withAnimation(Motion.heroReveal.delay(0.1)) { appeared = true }
        }
    }

    private var iconHeader: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .stroke(Color.appAlert.opacity(0.2), lineWidth: 2)
                    .frame(width: 108, height: 108)
                    .scaleEffect(appeared ? 1.15 : 1)
                    .opacity(appeared ? 0 : 0.6)

                Circle()
                    .fill(Color.appAlert.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "xmark.circle.fill")
                    .font(.bmUI(44))
                    .foregroundStyle(Color.appAlert)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Space.sm) {
                Text("Cancel this\nappointment?")
                    .font(.bmHero(26))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-3)

                Text("\(booking.style) with \(booking.braiderName)")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)

                HStack(spacing: Space.xs) {
                    Image(systemName: "calendar")
                        .font(.bmUI(11))
                    Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.bmUI(12, weight: .semibold))
                    Text("·")
                    Image(systemName: "clock")
                        .font(.bmUI(11))
                    Text(booking.time)
                        .font(.bmUI(12, weight: .semibold))
                }
                .font(.bmUI(12))
                .foregroundStyle(Color.appInkSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 8)
                .background(Color.appSurfaceElevated, in: Capsule())
                .padding(.top, Space.xs)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
    }

    private var reasonBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Reason (optional)")
            ZStack(alignment: .topLeading) {
                if reason.isEmpty {
                    Text("Let the braider know why…")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.appSmoke)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                }
                TextEditor(text: $reason)
                    .font(.bmUI(15))
                    .foregroundStyle(Color.appInk)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .frame(minHeight: 120)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animate(Motion.heroReveal.delay(0.2), value: appeared)
    }

    private var submitButton: some View {
        BMPrimaryButton(
            title: submitting ? "Sending…" : "Request cancellation",
            icon: "paperplane.fill",
            loading: submitting
        ) {
            submit()
        }
        .disabled(submitting)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animate(Motion.heroReveal.delay(0.25), value: appeared)
    }

    private func submit() {
        guard !session.uid.isEmpty else { return }
        submitting = true
        Haptic.press()
        Task {
            do {
                try await FirebaseManager.shared.requestCancellation(
                    bookingId: booking.id,
                    reason: reason.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    submitting = false
                    Haptic.success()
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    submitting = false
                    errorMessage = error.localizedDescription
                    Haptic.error()
                }
            }
        }
    }
}