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
    @State private var appeared = false

    private var total: Int {
        service.priceFrom + (includeHair ? 30 : 0) + (addBeads ? 15 : 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground(intensity: 0.5)

            VStack(spacing: 0) {
                BookingTopBar(step: 3) { dismiss() }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        header
                        summaryCard
                        addOnsCard
                        policyNote
                        Color.clear.frame(height: 170)
                    }
                }
            }

            confirmBar
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .task { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Review & confirm")
                .font(.bmDisplay(36, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Text("Check the details before you book.")
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .reveal(appeared, offset: 16)
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.md) {
                ZStack {
                    if service.imageUrl.isEmpty {
                        LinearGradient(
                            colors: [Color.bmRaised, Color.bmSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "sparkles")
                            .foregroundStyle(LinearGradient.bmGiltGradient)
                    } else {
                        RemoteImage(url: service.imageUrl)
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.bmDisplay(20, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        BMAvatar(url: braider.avatarUrl, size: 20, initials: bmInitials(braider.name))
                        Text(braider.name)
                            .font(.bmUI(13, weight: .medium))
                            .foregroundStyle(Color.bmTextDim)
                    }
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
            summaryRow(icon: "hourglass", label: "Duration",
                       value: "\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
        }
        .bmCard(radius: Radius.card)
        .padding(.horizontal, Space.lg)
        .reveal(appeared, delay: 0.08, offset: 22, blur: 0)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.bmUI(13, weight: .bold))
                .foregroundStyle(Color.bmGilt)
                .frame(width: 32, height: 32)
                .background(Color.bmGilt.opacity(0.13), in: Circle())
            Text(label)
                .font(.bmUI(14))
                .foregroundStyle(Color.bmTextDim)
            Spacer()
            Text(value)
                .font(.bmUI(14, weight: .semibold))
                .foregroundStyle(Color.bmText)
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
                BMDivider(inset: 64)
                toggleRow(icon: "circle.hexagongrid.fill", title: "Add beads",
                          subtitle: "Gold, silver or wood", price: 15, isOn: $addBeads)
            }
            .bmCard(radius: Radius.card)
            .padding(.horizontal, Space.lg)
        }
        .reveal(appeared, delay: 0.16, offset: 22, blur: 0)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, price: Int, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Color.bmOnGilt : Color.bmTextDim)
                .frame(width: 40, height: 40)
                .background {
                    if isOn.wrappedValue {
                        Circle().fill(LinearGradient.bmGiltGradient)
                    } else {
                        Circle().fill(Color.white.opacity(0.07))
                    }
                }
                .animation(Motion.press, value: isOn.wrappedValue)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                HStack(spacing: Space.xs) {
                    Text(subtitle)
                        .font(.bmUI(12))
                        .foregroundStyle(Color.bmTextDim)
                    Text("+£\(price)")
                        .font(.bmNum(12, weight: .bold))
                        .foregroundStyle(Color.bmGilt)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.bmGilt)
                .onChange(of: isOn.wrappedValue) { _, _ in Haptic.select() }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var policyNote: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "shield.checkered")
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(Color.bmGood)
            Text("Free cancellation up to 24 hours before your appointment.")
                .font(.bmUI(13))
                .foregroundStyle(Color.bmTextDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bmGood.opacity(0.09), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(Color.bmGood.opacity(0.25), lineWidth: 0.8)
        )
        .padding(.horizontal, Space.lg)
        .reveal(appeared, delay: 0.24, offset: 22, blur: 0)
    }

    private var confirmBar: some View {
        VStack(spacing: Space.md) {
            HStack(alignment: .lastTextBaseline) {
                Text("Total")
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
                Spacer()
                Text("£\(total)")
                    .font(.bmNum(34, weight: .bold))
                    .foregroundStyle(Color.bmText)
                    .contentTransition(.numericText(value: Double(total)))
                    .animation(Motion.press, value: total)
            }

            BMPrimaryButton(
                title: isBooking ? "Confirming…" : "Confirm booking",
                icon: isBooking ? nil : "checkmark",
                loading: isBooking
            ) {
                confirm()
            }
            .disabled(isBooking)
        }
        .padding(Space.md)
        .bmGlass(radius: Radius.modal, tint: Color.black.opacity(0.3))
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
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
