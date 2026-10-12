import SwiftUI
import PhotosUI

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
                ScrollView(showsIndicators: true) {
                    VStack(spacing: Space.lg) {
                        avatarSection
                        quickActions
                        infoSection
                        signOutButton
                        Text("BraidMe v1.0 · \(providerLabel) account")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appSmoke)
                            .padding(.top, Space.xs)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.md)
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInk)
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
            let uid = session.uid
            guard !uid.isEmpty else { return }
            Task {
                await fb.loadUser(uid: uid)
                await fb.loadBookings(uid: uid)
                await fb.loadSavedBraiders(uid: uid)
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: Space.md) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if avatarUrl.isEmpty {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 100, height: 100)
                        Text(initials)
                            .font(.bmDisplay(36, weight: .semibold))
                            .foregroundStyle(Color.appInkInverse)
                    } else {
                        RemoteImage(url: avatarUrl)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    }
                    Circle()
                        .stroke(Color.appAccent, lineWidth: 2)
                        .frame(width: 104, height: 104)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.appSurface, lineWidth: 3))
                        if uploadingAvatar {
                            ProgressView().tint(Color.appInkInverse).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.bmUI(13, weight: .semibold))
                                .foregroundStyle(Color.appInkInverse)
                        }
                    }
                }
                .disabled(uploadingAvatar)
                .offset(x: 4, y: 4)
            }

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Signed in with \(providerLabel)")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appAsh)
            }
        }
        .padding(.top, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal, value: appeared)
    }

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
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal.delay(0.05), value: appeared)
    }

    private func quickAction(icon: String, value: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptic.press()
            action()
        } label: {
            VStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Text(value)
                    .font(.bmDisplay(18, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text(label.uppercased())
                    .font(.bmUI(9, weight: .semibold))
                    .tracking(0.8)
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
            .opacity(enabled ? 1 : 0.6)
        }
        .buttonStyle(BMPressStyle(scale: 0.98))
        .disabled(!enabled)
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person", label: "Name", value: displayName)
            BMDivider(inset: 60)
            infoRow(icon: "envelope", label: "Email", value: userEmail)
            BMDivider(inset: 60)
            infoRow(icon: "calendar", label: "Age", value: userAge)
            BMDivider(inset: 60)
            infoRow(icon: "location", label: "City", value: userCity)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal.delay(0.10), value: appeared)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle().fill(Color.appAccentTint).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.bmUI(10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(Color.appAsh)
                Text(value)
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var signOutButton: some View {
        Button {
            Haptic.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.bmUI(13, weight: .semibold))
                Text("Sign Out")
                    .font(.bmUI(15, weight: .semibold))
            }
            .foregroundStyle(Color.appAlert)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.vertical, Space.xs)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appAlert.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(BMPressStyle())
        .padding(.top, Space.xs)
        .opacity(appeared ? 1 : 0)
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