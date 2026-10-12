import SwiftUI

// =============================================================================
// PaymentView — Step 3: confirm + add-ons, upgraded
// Glass confirm bar, animated total counter, toggle rows with fill animation.
// =============================================================================

struct PaymentView: View {
    let braider: Braider
    let service: BraidService
    let date: Date
    let time: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var includeHair = true
    @State private var addBeads = false
    @State private var isBooking = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    @State private var appeared = false

    private var total: Int {
        service.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                BookingProgressHeader(step: 3)
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        header
                        summaryCard
                        addOnsCard
                        policyNote
                        Color.clear.frame(height: 180)
                    }
                    .padding(.top, Space.md)
                }
            }

            confirmBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showConfirmation) {
            BookingConfirmationView(
                braider: braider,
                service: service,
                date: date,
                time: time,
                total: total
            )
        }
        .alert("Couldn't complete booking", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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
                Text("STEP 3 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.gold)
            }

            Text("Confirm")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            Text("Review your booking details")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.md) {
                if !service.imageUrl.isEmpty {
                    RemoteImage(url: service.imageUrl)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(braider.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appAsh)
                }
                Spacer()
            }
            .padding(Space.md)

            BMDivider()
            summaryRow(icon: "calendar", label: "Date",
                       value: date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            BMDivider(inset: 56)
            summaryRow(icon: "clock", label: "Time", value: time)
            BMDivider(inset: 56)
            summaryRow(icon: "timer", label: "Duration",
                       value: "\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        .padding(.horizontal, Space.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gold)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.appAsh)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Add-ons

    private var addOnsCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("ADD-ONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }
            .padding(.horizontal, Space.lg)

            VStack(spacing: 0) {
                toggleRow(icon: "scissors", title: "Hair included",
                          subtitle: "Premium braiding hair", price: 30, isOn: $includeHair)
                BMDivider(inset: 64)
                toggleRow(icon: "circle.grid.hex", title: "Add beads",
                          subtitle: "Gold, silver, or wood", price: 15, isOn: $addBeads)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
            .padding(.horizontal, Space.lg)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.20), value: appeared)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, price: Int, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(isOn.wrappedValue ? Color.gold.opacity(0.14) : Color.appBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Color.gold : Color.appAsh)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isOn.wrappedValue)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appInk)
                HStack(spacing: Space.xs) {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appAsh)
                    Text("+£\(price)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.gold)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.gold)
                .onChange(of: isOn.wrappedValue) { _, _ in Haptic.select() }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Policy note

    private var policyNote: some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gold)
            }
            Text("Free cancellation up to 24 hours before your appointment.")
                .font(.system(size: 12))
                .foregroundStyle(Color.appInkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Color.gold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.horizontal, Space.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.25), value: appeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Confirm bar

    private var confirmBar: some View {
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

            VStack(spacing: Space.md) {
                HStack {
                    Text("Total")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appAsh)
                    Spacer()
                    Text("£\(total)")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Color.appInk)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: total)
                }

                BMPrimaryButton(
                    title: isBooking ? "Confirming…" : "Confirm booking",
                    icon: "checkmark",
                    loading: isBooking
                ) {
                    confirm()
                }
                .disabled(isBooking)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .padding(.bottom, Space.xl)
            .background(Color.glassTintStrong)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Confirm

    private func confirm() {
        let uid = session.uid
        guard !uid.isEmpty else {
            errorMessage = "You need to be signed in."
            return
        }

        let customerName: String = {
            if let n = fb.currentUser?.displayName, !n.isEmpty { return n }
            if let n = session.displayName, !n.isEmpty { return n }
            return "Customer \(uid.prefix(6))"
        }()

        isBooking = true
        Haptic.press()

        fb.createBooking(
            braider: braider,
            date: date,
            time: time,
            service: service,
            price: total,
            uid: uid,
            customerName: customerName
        ) { success in
            isBooking = false
            if success {
                Haptic.success()
                showConfirmation = true
            } else {
                Haptic.error()
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }
}