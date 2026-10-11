import SwiftUI

struct UserInfoSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared

    @State private var appeared = false
    @State private var showSignOutConfirm = false
    @State private var showBookings = false
    @State private var showSaved = false

    private var displayName: String {
        fb.currentUser?.displayName ?? session.displayName ?? "BraidMe User"
    }

    private var userEmail: String {
        fb.currentUser?.email ?? session.email ?? "Not shared"
    }

    private var userAge: String {
        if let age = fb.currentUser?.age, age > 0 { return "\(age)" }
        let stored = UserDefaults.standard.integer(forKey: "userAge")
        return stored > 0 ? "\(stored)" : "—"
    }

    private var userCity: String { fb.currentUser?.city ?? "Not shared" }

    private var providerLabel: String {
        let p = fb.currentUser?.provider ?? detectedProvider
        switch p {
        case "apple": return "Apple"
        case "google": return "Google"
        case "email": return "Email"
        case "password": return "Email"
        default: return "Guest"
        }
    }

    private var providerIcon: String {
        switch providerLabel {
        case "Apple": return "applelogo"
        case "Google": return "g.circle.fill"
        case "Email": return "envelope.fill"
        default: return "person.fill"
        }
    }

    private var detectedProvider: String {
        guard let user = session.user else { return "guest" }
        let ids = user.providerData.compactMap { $0.providerID }
        if ids.contains("apple.com") { return "apple" }
        if ids.contains("google.com") { return "google" }
        if ids.contains("password") { return "email" }
        return "guest"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "BM" : r.uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()
                ambient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        avatarSection
                        quickActions
                        infoSection
                        signOutButton
                        Text("BraidMe v1.0 · \(providerLabel) account")
                            .font(AppTheme.sans(11))
                            .foregroundColor(AppTheme.stone)
                            .padding(.top, 8)
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showBookings) {
            BookingsListView().environmentObject(session)
        }
        .sheet(isPresented: $showSaved) {
            SavedBraidersView().environmentObject(session)
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to book a braider.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            let uid = session.uid
            guard !uid.isEmpty else { return }
            Task {
                await fb.loadUser(uid: uid)
                await fb.loadBookings(uid: uid)
                await fb.loadSavedBraiders(uid: uid)
            }
        }
    }

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 420, height: 420)
                .blur(radius: 50)
                .offset(x: -140, y: -180)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 380, height: 380)
                .blur(radius: 60)
                .offset(x: 160, y: 260)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
        .allowsHitTesting(false)
    }

    private var avatarSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.inkGradient)
                    .frame(width: 120, height: 120)
                Text(initials)
                    .font(AppTheme.serif(44))
                    .foregroundColor(.white)
                Circle()
                    .stroke(AppTheme.accent, lineWidth: 3)
                    .frame(width: 126, height: 126)

                ZStack {
                    Circle()
                        .fill(AppTheme.snow)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    Image(systemName: providerIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
                .offset(x: 44, y: 44)
            }
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)

            VStack(spacing: 6) {
                Text(displayName)
                    .font(AppTheme.serif(24))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Signed in with \(providerLabel)")
                    .font(AppTheme.sans(12, weight: .medium))
                    .foregroundColor(AppTheme.stone)
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction(
                icon: "calendar.badge.clock",
                value: "\(fb.bookings.count)",
                label: "Bookings"
            ) {
                showBookings = true
            }
            quickAction(
                icon: "heart.fill",
                value: "\(fb.savedBraiderIds.count)",
                label: "Saved"
            ) {
                showSaved = true
            }
            quickAction(
                icon: "star.fill",
                value: "New",
                label: "Member"
            ) {}
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func quickAction(icon: String, value: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(value)
                    .font(AppTheme.serif(20))
                    .foregroundColor(AppTheme.ink)
                Text(label.uppercased())
                    .font(AppTheme.sans(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(AppTheme.stone)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person.fill", label: "Name", value: displayName)
            divider
            infoRow(icon: "envelope.fill", label: "Email", value: userEmail)
            divider
            infoRow(icon: "calendar", label: "Age", value: userAge)
            divider
            infoRow(icon: "location.fill", label: "City", value: userCity)
        }
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.stone)
                Text(value)
                    .font(AppTheme.sans(15, weight: .medium))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Divider().background(AppTheme.hairline).padding(.leading, 64)
    }

    private var signOutButton: some View {
        Button {
            Haptics.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sign Out")
                    .font(AppTheme.sans(15, weight: .semibold))
            }
            .foregroundColor(AppTheme.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.snow)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.danger.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(SoftPress())
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
    }

    private func signOut() {
        fb.currentUser = nil
        fb.bookings = []
        fb.braiders = []
        fb.savedBraiderIds = []

        UserDefaults.standard.removeObject(forKey: "currentUid")
        UserDefaults.standard.removeObject(forKey: "appleUserId")
        UserDefaults.standard.removeObject(forKey: "userAge")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "locationPermissionDecision")

        SessionManager.shared.signOut()
        dismiss()
    }
}