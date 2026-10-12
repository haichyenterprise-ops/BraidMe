import SwiftUI

// =============================================================================
// BookingsListView — User's bookings, upgraded
// Underline filter tabs, colored date badges, staggered reveal, cancel flow.
// =============================================================================

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

                RadialGradient(
                    colors: [Color.gold.opacity(0.06), .clear],
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
                    Button {
                        Haptic.press()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .frame(width: 40, height: 40)
                            .background(Color.appSurface, in: Circle())
                            .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))
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
                withAnimation(.spring(response: 0.85, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
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
                Text("YOUR APPOINTMENTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.gold)
            }

            Text("My bookings")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            Text(verbatim: "\(fb.bookings.count) appointment\(fb.bookings.count == 1 ? "" : "s")")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Filter tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        filter = f
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(f.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(filter == f ? Color.appInk : Color.appAsh)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(filter == f ? Color.gold : Color.clear)
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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if loading && fb.bookings.isEmpty {
            VStack(spacing: Space.md) {
                ProgressView()
                    .tint(Color.gold)
                    .scaleEffect(1.1)
                Text("Loading your bookings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.appAsh)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            emptyState
        } else {
            listView
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Image(systemName: filter == .current ? "calendar.badge.plus" : "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.gold)
            }

            VStack(spacing: Space.xs) {
                Text(filter == .current ? "No upcoming bookings" : "No history yet")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)

                Text(filter == .current
                     ? "Book a braider from the map to get started."
                     : "Your completed appointments will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Space.xl)
            }
        }
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
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.85)
                            .delay(Double(index) * 0.06),
                        value: appeared
                    )
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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Booking Card
// ═══════════════════════════════════════════════════════════════════

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
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "scissors")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appSmoke)
                        Text(booking.braiderName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appAsh)
                    }

                    HStack(spacing: Space.xs) {
                        Text("£\(booking.price)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.gold)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text(booking.time)
                            .font(.system(size: 13))
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
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Message")
                                    .font(.system(size: 13, weight: .semibold))
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
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .semibold))
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
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.appInkInverse.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(.system(size: 22, weight: .bold, design: .serif))
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
        if Calendar.current.isDateInToday(booking.date) { return Color.gold }
        return Color.appInk
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", Color.appSignal)
            case "completed": return ("Completed", Color.appAsh)
            case "cancelled": return ("Cancelled", Color.appAlert)
            case "cancellation_requested": return ("Pending", Color.gold)
            case "cancellation_denied": return ("Denied", Color.appAlert)
            default: return (booking.status.capitalized, Color.appAsh)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 0.5))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cancel Booking Sheet
// ═══════════════════════════════════════════════════════════════════

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
                    .font(.system(size: 15, weight: .medium))
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
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
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
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appAlert)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Space.sm) {
                Text("Cancel this\nappointment?")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-3)

                Text("\(booking.style) with \(booking.braiderName)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)

                HStack(spacing: Space.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, weight: .semibold))
                    Text("·")
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(booking.time)
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 12))
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
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("REASON (OPTIONAL)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAsh)
            }
            ZStack(alignment: .topLeading) {
                if reason.isEmpty {
                    Text("Let the braider know why…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appSmoke)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                }
                TextEditor(text: $reason)
                    .font(.system(size: 15))
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