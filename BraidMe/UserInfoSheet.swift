import SwiftUI
import PhotosUI

// =============================================================================
// UserInfoSheet — Account sheet, upgraded
// Gradient-ring avatar, quick-action tiles, editorial info rows, breathing sign-out.
// =============================================================================

struct UserInfoSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared

    @State private var appeared = false
    @State private var showSignOutConfirm = false
    @State private var showBookings = false
    @State private var showSaved = false

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var uploadingAvatar = false
    @State private var avatarError: String?

    // Breathing ring rotation
    @State private var ringRotation: Double = 0
    // Ambient orb motion
    @State private var ambientOffset: CGSize = .zero

    private var displayName: String {
        fb.currentUser?.displayName ?? session.displayName ?? "BraidMe User"
    }
    private var userEmail: String {
        fb.currentUser?.email ?? session.email ?? "Not shared"
    }
    private var userAge: String {
        if let age = fb.currentUser?.age, age > 0 { return "\(age)" }
        let s = UserDefaults.standard.integer(forKey: "userAge")
        return s > 0 ? "\(s)" : "—"
    }
    private var userCity: String { fb.currentUser?.city ?? "Not shared" }
    private var avatarUrl: String { fb.currentUser?.avatarUrl ?? "" }

    private var providerLabel: String {
        let p = fb.currentUser?.provider ?? detectedProvider
        switch p {
        case "apple": return "Apple"
        case "google": return "Google"
        case "email", "password": return "Email"
        default: return "Guest"
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
        return r.isEmpty ? "·" : r.uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Ambient orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.gold.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 520)
                    .offset(x: ambientOffset.width, y: ambientOffset.height - 180)
                    .blur(radius: 30)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: true) {
                    VStack(spacing: Space.lg) {
                        avatarSection
                        quickActions
                        infoSection
                        signOutButton
                        footer
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.md)
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
        .alert("Couldn't upload", isPresented: Binding(
            get: { avatarError != nil },
            set: { if !$0 { avatarError = nil } }
        )) {
            Button("OK", role: .cancel) { avatarError = nil }
        } message: {
            Text(avatarError ?? "")
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task { await uploadAvatar(newValue) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                ambientOffset = CGSize(width: 20, height: 30)
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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: Space.md) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    // Rotating gold gradient ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.goldLight.opacity(0.85),
                                    Color.gold.opacity(0.3),
                                    Color.goldDeep.opacity(0.6),
                                    Color.gold.opacity(0.3),
                                    Color.goldLight.opacity(0.85)
                                ],
                                center: .center,
                                angle: .degrees(ringRotation)
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 116, height: 116)

                    // Static outer soft ring
                    Circle()
                        .stroke(Color.gold.opacity(0.15), lineWidth: 1)
                        .frame(width: 122, height: 122)

                    if avatarUrl.isEmpty {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 108, height: 108)
                        Text(initials)
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundStyle(Color.appInkInverse)
                    } else {
                        RemoteImage(url: avatarUrl)
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                    }
                }
                .shadow(color: Color.gold.opacity(0.25), radius: 20, y: 8)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.appSurface, lineWidth: 3))
                            .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
                        if uploadingAvatar {
                            ProgressView().tint(Color.appInkInverse).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appInkInverse)
                        }
                    }
                }
                .disabled(uploadingAvatar)
                .offset(x: 4, y: 4)
            }

            VStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gold)
                    Text("\(providerLabel) account")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                }
            }
        }
        .padding(.top, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: Space.sm) {
            quickAction(icon: "calendar", value: "\(fb.bookings.count)", label: "Bookings", enabled: true) {
                showBookings = true
            }
            quickAction(icon: "heart.fill", value: "\(fb.savedBraiderIds.count)", label: "Saved", enabled: true) {
                showSaved = true
            }
            quickAction(icon: "star.fill", value: "New", label: "Member", enabled: false) {}
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    private func quickAction(icon: String, value: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptic.press()
            action()
        } label: {
            VStack(spacing: Space.xs) {
                ZStack {
                    Circle()
                        .fill(Color.gold.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .contentTransition(.numericText())
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.appAsh)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(enabled ? 0.06 : 0), radius: 12, y: 4)
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(BMPressStyle(scale: 0.98))
        .disabled(!enabled)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Info rows

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person.fill", label: "Name", value: displayName)
            BMDivider(inset: 64)
            infoRow(icon: "envelope.fill", label: "Email", value: userEmail)
            BMDivider(inset: 64)
            infoRow(icon: "calendar", label: "Age", value: userAge)
            BMDivider(inset: 64)
            infoRow(icon: "location.fill", label: "City", value: userCity)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.20), value: appeared)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.appAsh)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Sign out + footer

    private var signOutButton: some View {
        Button {
            Haptic.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sign Out")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.appAlert)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(Color.appAlert.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appAlert.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(BMPressStyle())
        .padding(.top, Space.xs)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.25), value: appeared)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("BraidMe")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Color.appInk)
            Text("v1.0 · Made with care")
                .font(.system(size: 11))
                .foregroundStyle(Color.appSmoke)
        }
        .padding(.top, Space.md)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Actions

    private func signOut() {
        fb.currentUser = nil
        fb.bookings = []
        fb.braiders = []
        fb.savedBraiderIds = []
        SessionManager.shared.hardSignOut()
        dismiss()
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        await MainActor.run { uploadingAvatar = true }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "avatar", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not read photo."])
            }
            let url = try await ImageUploader.upload(image)
            let uid = session.uid
            guard !uid.isEmpty else {
                throw NSError(domain: "avatar", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "You need to be signed in."])
            }
            try await fb.updateUser(uid: uid, data: ["avatarUrl": url])
            await fb.loadUser(uid: uid)
            await MainActor.run {
                uploadingAvatar = false
                Haptic.success()
            }
        } catch {
            await MainActor.run {
                uploadingAvatar = false
                avatarError = error.localizedDescription
                Haptic.error()
            }
        }
    }
}