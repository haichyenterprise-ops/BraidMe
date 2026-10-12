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
        case current = "Current"
        case past = "Past"
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
                VStack(spacing: 0) {
                    header
                    filterTabs
                    if loading && fb.bookings.isEmpty {
                        BMLoadingView(message: "Loading bookings")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        listView
                    }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInk)
                }
            }
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
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("MY BOOKINGS")
                .font(.bmUI(11, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Color.appAccent)
            Text("Your appointments")
                .font(.bmDisplay(26, weight: .semibold))
                .foregroundStyle(Color.appInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.md)
    }

    private var filterTabs: some View {
        HStack(spacing: Space.xs) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptic.select()
                    withAnimation(Motion.press) { filter = f }
                } label: {
                    Text(f.rawValue)
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(filter == f ? Color.appInkInverse : Color.appInk)
                        .padding(.horizontal, Space.md)
                        .frame(minHeight: 34)
                        .padding(.vertical, 4)
                        .background(filter == f ? Color.appInk : Color.appSurface, in: Capsule())
                        .overlay(
                            Capsule().stroke(filter == f ? Color.clear : Color.appDivider, lineWidth: 0.5)
                        )
                }
                .buttonStyle(BMPressStyle(scale: 0.97))
            }
            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    private var emptyState: some View {
        BMEmptyState(
            icon: filter == .current ? "calendar.badge.plus" : "clock",
            title: filter == .current ? "No upcoming bookings" : "No past bookings",
            message: filter == .current
                ? "Book a braider from the map to get started."
                : "Completed bookings will show here."
        )
        .frame(maxHeight: .infinity)
    }

    private var listView: some View {
        ScrollView(showsIndicators: true) {
            LazyVStack(spacing: Space.sm) {
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
                    .offset(y: appeared ? 0 : 16)
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

// MARK: - Booking card

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
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.style)
                        .font(.bmDisplay(18, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "scissors")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appSmoke)
                        Text(booking.braiderName)
                            .font(.bmUI(13, weight: .medium))
                            .foregroundStyle(Color.appAsh)
                    }
                    HStack(spacing: Space.xs) {
                        Text("£\(booking.price)")
                            .font(.bmMono(14, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        Text("·").foregroundStyle(Color.appSmoke)
                        Text(booking.time)
                            .font(.bmUI(13))
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                statusBadge
            }

            if !isPast {
                HStack(spacing: Space.xs) {
                    if canMessage {
                        Button(action: onMessage) {
                            HStack(spacing: Space.xxs) {
                                Image(systemName: "message.fill")
                                    .font(.bmUI(11, weight: .semibold))
                                Text("Message")
                                    .font(.bmUI(13, weight: .semibold))
                            }
                            .foregroundStyle(Color.appInkInverse)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                            .background(Color.appInk, in: RoundedRectangle(cornerRadius: Radius.button))
                        }
                        .buttonStyle(BMPressStyle())
                    }
                    if canCancel {
                        Button(action: onCancel) {
                            HStack(spacing: Space.xxs) {
                                Image(systemName: "xmark.circle")
                                    .font(.bmUI(11, weight: .semibold))
                                Text("Cancel")
                                    .font(.bmUI(13, weight: .semibold))
                            }
                            .foregroundStyle(Color.appAlert)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                            .background(Color.appAlert.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.button)
                                    .stroke(Color.appAlert.opacity(0.3), lineWidth: 1)
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
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.bmUI(9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.appInkInverse.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(.bmDisplay(20, weight: .semibold))
                .foregroundStyle(Color.appInkInverse)
        }
        .frame(width: 52, height: 60)
        .background(monthColor)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
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
        return HStack(spacing: Space.xxs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.bmUI(10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Cancel sheet

struct CancelBookingSheet: View {
    let booking: Booking
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var reason = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
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
    }

    private var iconHeader: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle().fill(Color.appAlert.opacity(0.12)).frame(width: 80, height: 80)
                Image(systemName: "xmark.circle.fill")
                    .font(.bmUI(36))
                    .foregroundStyle(Color.appAlert)
            }
            VStack(spacing: Space.xs) {
                Text("Cancel this booking?")
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("\(booking.style) with \(booking.braiderName) · \(booking.date.formatted(date: .abbreviated, time: .omitted)) at \(booking.time)")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Space.lg)
            }
        }
    }

    private var reasonBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
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
                    .frame(minHeight: 110)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
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