import SwiftUI

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
                        Color.clear.frame(height: 140)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Confirm booking")
                .font(.bmDisplay(28, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("Review your details before confirming")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.md) {
                if !service.imageUrl.isEmpty {
                    RemoteImage(url: service.imageUrl)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(braider.name)
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appAsh)
                }
                Spacer()
            }
            .padding(Space.md)

            BMDivider()
            summaryRow(icon: "calendar", label: "Date",
                       value: date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            BMDivider(inset: 52)
            summaryRow(icon: "clock", label: "Time", value: time)
            BMDivider(inset: 52)
            summaryRow(icon: "timer", label: "Duration",
                       value: "\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .padding(.horizontal, Space.lg)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .frame(width: 20)
            Text(label)
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
            Spacer()
            Text(value)
                .font(.bmUI(13, weight: .medium))
                .foregroundStyle(Color.appInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var addOnsCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Add-ons")
                .padding(.horizontal, Space.lg)

            VStack(spacing: 0) {
                toggleRow(icon: "scissors", title: "Hair included",
                          subtitle: "Premium braiding hair", price: 30, isOn: $includeHair)
                BMDivider(inset: 56)
                toggleRow(icon: "circle.grid.hex", title: "Add beads",
                          subtitle: "Gold, silver, or wood", price: 15, isOn: $addBeads)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .padding(.horizontal, Space.lg)
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, price: Int, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(isOn.wrappedValue ? Color.appAccentTint : Color.appBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Color.appAccent : Color.appAsh)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(Color.appInk)
                HStack(spacing: Space.xs) {
                    Text(subtitle)
                        .font(.bmUI(12))
                        .foregroundStyle(Color.appAsh)
                    Text("+£\(price)")
                        .font(.bmMono(11, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.appAccent)
                .onChange(of: isOn.wrappedValue) { _, _ in Haptic.select() }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var policyNote: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "info.circle")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
            Text("Free cancellation up to 24 hours before your appointment.")
                .font(.bmUI(12))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Color.appAccentTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.horizontal, Space.lg)
    }

    private var confirmBar: some View {
        VStack(spacing: 0) {
            BMDivider()
            VStack(spacing: Space.md) {
                HStack {
                    Text("Total")
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appAsh)
                    Spacer()
                    Text("£\(total)")
                        .font(.bmDisplay(26, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .contentTransition(.numericText())
                        .animation(Motion.press, value: total)
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
            .background(Color.appSurface)
        }
    }

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