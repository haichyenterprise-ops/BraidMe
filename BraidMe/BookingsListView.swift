import SwiftUI

struct BookingsListView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Namespace private var segmentNS

    @State private var filter: Filter = .current
    @State private var activeChat: Booking?
    @State private var cancelBooking: Booking?
    @State private var appeared = false
    @State private var loading = false

    enum Filter: String, CaseIterable {
        case current = "Upcoming"
        case past = "Past"
    }

    private func bookings(for f: Filter) -> [Booking] {
        let now = Calendar.current.startOfDay(for: Date())
        return fb.bookings.filter { b in
            let isPast = b.date < now || b.status == "completed" || b.status == "cancelled"
            return f == .current ? !isPast : isPast
        }
        .sorted { f == .current ? $0.date < $1.date : $0.date > $1.date }
    }

    private var filtered: [Booking] { bookings(for: filter) }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: 0.45)

                VStack(spacing: 0) {
                    BMSheetBar(title: "Bookings", subtitle: "Your appointments") {
                        dismiss()
                    }
                    segmentControl
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
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeChat) { booking in
                ChatView(booking: booking, currentUserId: session.uid)
                    .presentationBackground(Color.bmBase)
                    .presentationCornerRadius(Radius.modal)
            }
            .sheet(item: $cancelBooking) { booking in
                CancelBookingSheet(booking: booking) { cancelBooking = nil }
                    .presentationBackground(Color.bmBase)
                    .presentationCornerRadius(Radius.modal)
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

    // MARK: - Segmented control

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptic.select()
                    withAnimation(Motion.sheet) { filter = f }
                } label: {
                    HStack(spacing: 6) {
                        Text(f.rawValue)
                            .font(.bmUI(14, weight: .bold))
                        Text("\(bookings(for: f).count)")
                            .font(.bmNum(12, weight: .bold))
                            .padding(.horizontal, 7)
                            .frame(minWidth: 22, minHeight: 20)
                            .background(
                                (filter == f ? Color.bmOnGilt.opacity(0.18) : Color.white.opacity(0.10)),
                                in: Capsule()
                            )
                    }
                    .foregroundStyle(filter == f ? Color.bmOnGilt : Color.bmTextDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background {
                        if filter == f {
                            Capsule()
                                .fill(LinearGradient.bmGiltGradient)
                                .matchedGeometryEffect(id: "segment", in: segmentNS)
                        }
                    }
                }
                .buttonStyle(BMPressStyle(scale: 0.97, dim: 0))
            }
        }
        .padding(4)
        .bmGlass(radius: 26)
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    private var emptyState: some View {
        BMEmptyState(
            icon: filter == .current ? "calendar.badge.plus" : "clock.arrow.circlepath",
            title: filter == .current ? "Nothing booked yet" : "No past bookings",
            message: filter == .current
                ? "Find a braider on the map and your next appointment will show up here."
                : "Completed and cancelled bookings will show here."
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
                    .reveal(appeared, delay: Motion.stagger(index), offset: 24, blur: 0)
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

    private var isDimmed: Bool {
        booking.status == "cancelled" || booking.status == "cancellation_denied"
            || booking.date < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.md) {
                dateBadge

                VStack(alignment: .leading, spacing: 6) {
                    statusBadge
                    Text(booking.style)
                        .font(.bmDisplay(20, weight: .semibold))
                        .foregroundStyle(isDimmed ? Color.bmTextDim : Color.bmText)
                        .lineLimit(2)
                    HStack(spacing: 5) {
                        Image(systemName: "scissors")
                            .font(.bmUI(11, weight: .bold))
                            .foregroundStyle(Color.bmTextFaint)
                        Text(booking.braiderName)
                            .font(.bmUI(14, weight: .medium))
                            .foregroundStyle(Color.bmTextDim)
                    }
                    HStack(spacing: Space.sm) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.bmUI(11, weight: .semibold))
                            Text(booking.time)
                                .font(.bmNum(13, weight: .semibold))
                        }
                        .foregroundStyle(Color.bmTextDim)
                        Text("£\(booking.price)")
                            .font(.bmNum(14, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            if !isPast && (canMessage || canCancel) {
                HStack(spacing: Space.xs) {
                    if canMessage {
                        Button(action: onMessage) {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.bmUI(12, weight: .bold))
                                Text("Message")
                                    .font(.bmUI(14, weight: .bold))
                            }
                            .foregroundStyle(Color.bmOnGilt)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(LinearGradient.bmGiltGradient, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                        }
                        .buttonStyle(BMPressStyle())
                    }
                    if canCancel {
                        Button(action: onCancel) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.bmUI(12, weight: .bold))
                                Text("Cancel")
                                    .font(.bmUI(14, weight: .bold))
                            }
                            .foregroundStyle(Color.bmBad)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.bmBad.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                    .strokeBorder(Color.bmBad.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(BMPressStyle())
                    }
                }
            }
        }
        .padding(Space.md)
        .bmCard(radius: Radius.card)
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)))
                .font(.bmUI(12, weight: .bold))
                .foregroundStyle(badgeText.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(.bmDisplay(28, weight: .semibold))
                .foregroundStyle(badgeText)
            Text(booking.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.bmUI(11, weight: .semibold))
                .foregroundStyle(badgeText.opacity(0.75))
        }
        .frame(width: 60, height: 74)
        .background {
            if isDimmed {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            } else if Calendar.current.isDateInToday(booking.date) {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(LinearGradient.bmGiltGradient)
            } else {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.bmRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .strokeBorder(Color.bmGilt.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }

    private var badgeText: Color {
        if isDimmed { return Color.bmTextDim }
        if Calendar.current.isDateInToday(booking.date) { return Color.bmOnGilt }
        return Color.bmText
    }

    private var statusBadge: some View {
        let info: (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", Color.bmGood)
            case "completed": return ("Completed", Color.bmTextDim)
            case "cancelled": return ("Cancelled", Color.bmBad)
            case "cancellation_requested": return ("Pending", Color.bmGilt)
            case "cancellation_denied": return ("Denied", Color.bmBad)
            default: return (booking.status.capitalized, Color.bmTextDim)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(info.1).frame(width: 6, height: 6)
            Text(info.0)
                .font(.bmUI(11, weight: .bold))
                .foregroundStyle(info.1)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(info.1.opacity(0.14), in: Capsule())
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
        ZStack {
            AuroraBackground(intensity: 0.35)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.lg) {
                    HStack {
                        Spacer()
                        BMIconButton(icon: "xmark", size: 40, iconSize: 13) {
                            dismiss()
                            onDismiss()
                        }
                    }
                    iconHeader
                    reasonBlock
                    submitButton
                }
                .padding(Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Request sent", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
                onDismiss()
            }
        } message: {
            Text("Your cancellation request has been sent to \(booking.braiderName). They'll respond shortly.")
        }
        .alert("Couldn't send request", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var iconHeader: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.bmBad.opacity(0.25))
                    .frame(width: 90, height: 90)
                    .blur(radius: 24)
                Circle()
                    .fill(Color.bmSurface)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().strokeBorder(Color.bmBad.opacity(0.4), lineWidth: 1))
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.bmBad)
            }
            VStack(spacing: Space.xs) {
                Text("Cancel this booking?")
                    .font(.bmDisplay(28, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                Text("\(booking.style) with \(booking.braiderName) on \(booking.date.formatted(date: .abbreviated, time: .omitted)) at \(booking.time)")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.bmTextDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Space.md)
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
                        .foregroundStyle(Color.bmTextFaint)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $reason)
                    .font(.bmUI(15))
                    .foregroundStyle(Color.bmText)
                    .tint(Color.bmGilt)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .frame(minHeight: 120)
            }
            .background(Color.bmSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        BMPrimaryButton(
            title: submitting ? "Sending…" : "Request cancellation",
            icon: submitting ? nil : "paperplane.fill",
            loading: submitting,
            shine: false
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
