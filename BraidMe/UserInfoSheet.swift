import SwiftUI
import PhotosUI

struct UserInfoSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared

    @State private var appeared = false
    @State private var spinRing = false
    @State private var showSignOutConfirm = false
    @State private var showBookings = false
    @State private var showSaved = false

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var uploadingAvatar = false
    @State private var avatarError: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var providerIcon: String {
        switch providerLabel {
        case "Apple": return "apple.logo"
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

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: 0.6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        topBar
                        avatarSection
                        quickActions
                        infoSection
                        signOutButton
                        Text("BraidMe 1.0")
                            .font(.bmUI(12, weight: .medium))
                            .foregroundStyle(Color.bmTextFaint)
                            .padding(.top, Space.xxs)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showBookings) {
            BookingsListView().environmentObject(session)
                .presentationBackground(Color.bmBase)
                .presentationCornerRadius(Radius.modal)
        }
        .sheet(isPresented: $showSaved) {
            SavedBraidersView().environmentObject(session)
                .presentationBackground(Color.bmBase)
                .presentationCornerRadius(Radius.modal)
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
            appeared = true
            if !reduceMotion {
                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                    spinRing = true
                }
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Profile")
                .font(.bmDisplay(30, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Spacer()
            BMIconButton(icon: "xmark", size: 40, iconSize: 13) { dismiss() }
        }
        .padding(.top, Space.lg)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: Space.md) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [Color.bmGilt, Color.bmEmber, Color.bmOrchid, Color.bmGilt],
                                center: .center
                            ),
                            lineWidth: 3.5
                        )
                        .frame(width: 128, height: 128)
                        .rotationEffect(.degrees(spinRing ? 360 : 0))

                    Circle()
                        .fill(Color.bmGilt.opacity(0.22))
                        .frame(width: 110, height: 110)
                        .blur(radius: 26)

                    BMAvatar(url: avatarUrl, size: 112, initials: bmInitials(displayName))
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.bmGiltGradient)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().strokeBorder(Color.bmBase, lineWidth: 3))
                        if uploadingAvatar {
                            BMSpinner(color: Color.bmOnGilt, size: 15)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.bmUI(14, weight: .bold))
                                .foregroundStyle(Color.bmOnGilt)
                        }
                    }
                }
                .disabled(uploadingAvatar)
                .offset(x: 2, y: 2)
            }

            VStack(spacing: 6) {
                Text(displayName)
                    .font(.bmDisplay(28, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                BMTag(text: "Signed in with \(providerLabel)", icon: providerIcon, tint: Color.bmOrchid)
            }
        }
        .padding(.top, Space.xs)
        .reveal(appeared, offset: 16)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: Space.sm) {
            quickTile(icon: "calendar", value: "\(fb.bookings.count)", label: "Bookings", tint: Color.bmGilt) {
                showBookings = true
            }
            quickTile(icon: "heart.fill", value: "\(fb.savedBraiderIds.count)", label: "Saved", tint: Color.bmBad) {
                showSaved = true
            }
            quickTile(icon: providerIcon, value: providerLabel, label: "Sign-in", tint: Color.bmOrchid, action: nil)
        }
        .reveal(appeared, delay: 0.06)
    }

    private func quickTile(
        icon: String,
        value: String,
        label: String,
        tint: Color,
        action: (() -> Void)?
    ) -> some View {
        Button {
            guard let action else { return }
            Haptic.press()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.bmUI(15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.15), in: Circle())
                Text(value)
                    .font(.bmNum(18, weight: .bold))
                    .foregroundStyle(Color.bmText)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .bmCard(radius: Radius.card)
        }
        .buttonStyle(BMPressStyle(scale: 0.96))
        .disabled(action == nil)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person.fill", label: "Name", value: displayName)
            BMDivider(inset: 62)
            infoRow(icon: "envelope.fill", label: "Email", value: userEmail)
            BMDivider(inset: 62)
            infoRow(icon: "birthday.cake.fill", label: "Age", value: userAge)
            BMDivider(inset: 62)
            infoRow(icon: "location.fill", label: "City", value: userCity)
        }
        .bmCard(radius: Radius.card)
        .reveal(appeared, delay: 0.12)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.bmUI(13, weight: .bold))
                .foregroundStyle(Color.bmGilt)
                .frame(width: 34, height: 34)
                .background(Color.bmGilt.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
                Text(value)
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            Haptic.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.bmUI(14, weight: .semibold))
                Text("Sign out")
                    .font(.bmUI(16, weight: .semibold))
            }
            .foregroundStyle(Color.bmBad)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(Color.bmBad.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Color.bmBad.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(BMPressStyle())
        .reveal(appeared, delay: 0.18)
    }

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
