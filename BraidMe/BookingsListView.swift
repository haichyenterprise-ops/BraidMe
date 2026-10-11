import SwiftUI

struct BookingsListView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

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
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    filterTabs

                    if loading && fb.bookings.isEmpty {
                        loadingState
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        listView
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeChat) { booking in
                ChatView(booking: booking, currentUserId: session.uid)
            }
            .sheet(item: $cancelBooking) { booking in
                CancelBookingSheet(booking: booking) {
                    cancelBooking = nil
                }
            }
            .task {
                let uid = session.uid
                guard !uid.isEmpty else { return }
                loading = true
                await fb.loadBookings(uid: uid)
                loading = false
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MY BOOKINGS")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundColor(AppTheme.accentDeep)
            Text("Your appointments")
                .font(AppTheme.serif(28))
                .foregroundColor(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        filter = f
                    }
                } label: {
                    Text(f.rawValue)
                        .font(AppTheme.sans(13, weight: .semibold))
                        .foregroundColor(filter == f ? .white : AppTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(filter == f ? AppTheme.ink : AppTheme.snow, in: Capsule())
                        .overlay(
                            Capsule().stroke(filter == f ? Color.clear : AppTheme.hairline, lineWidth: 0.5)
                        )
                }
                .buttonStyle(SoftPress())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(AppTheme.accent)
            Text("Loading…").font(AppTheme.sans(13)).foregroundColor(AppTheme.slate)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                Image(systemName: filter == .current ? "calendar.badge.plus" : "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 8) {
                Text(filter == .current ? "No upcoming bookings" : "No past bookings")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text(filter == .current
                     ? "Book a braider from the map to get started."
                     : "Completed bookings will show here.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, booking in
                    BookingCardView(booking: booking, isPast: filter == .past) {
                        Haptics.soft()
                        activeChat = booking
                    } onCancel: {
                        Haptics.warning()
                        cancelBooking = booking
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.7, dampingFraction: 0.85)
                            .delay(Double(idx) * 0.05),
                        value: appeared
                    )
                }
                Color.clear.frame(height: 120)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
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
        // Can only message once booking is confirmed and not cancelled
        booking.status == "confirmed" || booking.status == "cancellation_requested"
    }

    private var canCancel: Bool {
        booking.status == "confirmed" && booking.date > Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                dateBadge
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.style)
                        .font(AppTheme.serif(18))
                        .foregroundColor(AppTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "scissors")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.stone)
                        Text(booking.braiderName)
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                    }

                    HStack(spacing: 8) {
                        Text("£\(booking.price)")
                            .font(AppTheme.sans(15, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text(booking.time)
                            .font(AppTheme.sans(13))
                            .foregroundColor(AppTheme.slate)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                statusBadge
            }

            if !isPast {
                HStack(spacing: 10) {
                    if canMessage {
                        Button(action: onMessage) {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Message")
                                    .font(AppTheme.sans(13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.inkGradient, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(SoftPress())
                    }

                    if canCancel {
                        Button(action: onCancel) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Cancel")
                                    .font(AppTheme.sans(13, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.danger.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(SoftPress())
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(AppTheme.serif(22))
                .foregroundColor(.white)
        }
        .frame(width: 54, height: 62)
        .background(monthColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var monthColor: Color {
        if booking.status == "cancelled" || booking.status == "cancellation_denied" {
            return AppTheme.stone
        }
        if booking.date < Calendar.current.startOfDay(for: Date()) {
            return AppTheme.stone
        }
        if Calendar.current.isDateInToday(booking.date) {
            return AppTheme.accent
        }
        return AppTheme.ink
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", AppTheme.success)
            case "completed": return ("Completed", AppTheme.slate)
            case "cancelled": return ("Cancelled", AppTheme.danger)
            case "cancellation_requested": return ("Pending cancel", AppTheme.warn)
            case "cancellation_denied": return ("Cancel denied", AppTheme.rose)
            default: return (booking.status.capitalized, AppTheme.stone)
            }
        }()

        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(0.4)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Cancel booking sheet

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
                AppTheme.cloud.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        iconHeader
                        reasonBlock
                        submitButton
                    }
                    .padding(20)
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
                    .font(AppTheme.sans(15, weight: .medium))
                    .foregroundColor(AppTheme.slate)
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
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.danger.opacity(0.12)).frame(width: 90, height: 90)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.danger)
            }

            VStack(spacing: 6) {
                Text("Cancel this booking?")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text("\(booking.style) with \(booking.braiderName) · \(booking.date.formatted(date: .abbreviated, time: .omitted)) at \(booking.time)")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var reasonBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Reason (optional)")
            ZStack(alignment: .topLeading) {
                if reason.isEmpty {
                    Text("Let the braider know why…")
                        .font(AppTheme.sans(15))
                        .foregroundColor(AppTheme.stone.opacity(0.7))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $reason)
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 110)
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        PrimaryButton(
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
        Haptics.medium()

        Task {
            do {
                try await FirebaseManager.shared.requestCancellation(
                    bookingId: booking.id,
                    reason: reason.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    submitting = false
                    Haptics.success()
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    submitting = false
                    errorMessage = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }
}