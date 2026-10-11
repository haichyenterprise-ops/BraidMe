import SwiftUI

struct UserInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        avatarSection
                        infoSection
                        statsSection
                        signOutButton
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
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            if let uid = fb.currentUid, !uid.isEmpty {
                Task { await fb.loadUser(uid: uid) }
            }
        }
    }

    // MARK: - Avatar

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
            }
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)

            VStack(spacing: 6) {
                Text(fb.currentUser?.displayName ?? "BraidMe User")
                    .font(AppTheme.serif(24))
                    .foregroundColor(AppTheme.ink)
                providerBadge
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var initials: String {
        guard let name = fb.currentUser?.displayName, !name.isEmpty else { return "BM" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var providerBadge: some View {
        let provider = fb.currentUser?.provider ?? "guest"
        let (icon, label): (String, String) = {
            switch provider {
            case "apple": return ("applelogo", "Signed in with Apple")
            case "google": return ("g.circle.fill", "Signed in with Google")
            default: return ("person.fill", "Guest account")
            }
        }()

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(AppTheme.sans(12, weight: .semibold))
        }
        .foregroundColor(AppTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.mist, in: Capsule())
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person.fill", label: "Name",
                    value: fb.currentUser?.displayName ?? "—")
            divider
            infoRow(icon: "envelope.fill", label: "Email",
                    value: fb.currentUser?.email ?? "Not shared")
            divider
            infoRow(icon: "calendar", label: "Age",
                    value: fb.currentUser.map { "\($0.age)" } ?? "—")
            divider
            infoRow(icon: "location.fill", label: "City",
                    value: fb.currentUser?.city ?? "Not shared")
        }
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(icon: "calendar.badge.clock", value: "\(fb.bookings.count)", label: "BOOKINGS")
            statCard(icon: "heart.fill", value: "0", label: "SAVED")
            statCard(icon: "star.fill", value: "New", label: "MEMBER")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.accent)
            Text(value)
                .font(AppTheme.serif(20))
                .foregroundColor(AppTheme.ink)
            Text(label)
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(AppTheme.stone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            Haptics.warning()
            signOut()
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.danger.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SoftPress())
        .padding(.top, 8)
    }

    private func signOut() {
        UserDefaults.standard.removeObject(forKey: "currentUid")
        UserDefaults.standard.removeObject(forKey: "appleUserId")
        UserDefaults.standard.removeObject(forKey: "userAge")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "locationPermissionDecision")

        fb.currentUser = nil
        fb.bookings = []
        fb.braiders = []

        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .braidMeSignOut, object: nil)
        }
    }
}

extension Notification.Name {
    static let braidMeSignOut = Notification.Name("BraidMeSignOut")
}