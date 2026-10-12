import SwiftUI

// =============================================================================
// WriteReviewSheet — Review composer, upgraded
// Oversized glowing stars, live rating label, spring validation, gold accents.
// =============================================================================

struct WriteReviewSheet: View {
    let braider: Braider
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var rating: Int = 5
    @State private var text: String = ""
    @State private var styleDone: String = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var appeared = false

    private var canSubmit: Bool {
        rating > 0 && text.trimmingCharacters(in: .whitespaces).count >= 5
    }

    private var disabledHint: String? {
        if rating == 0 { return "Add a star rating to continue" }
        if text.trimmingCharacters(in: .whitespaces).count < 5 { return "Write at least a few words" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Ambient gradient
                RadialGradient(
                    colors: [Color.gold.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: true) {
                    VStack(spacing: Space.lg) {
                        header
                        starsPicker
                        textBlock
                        styleBlock
                        submitArea
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(Space.lg)
                }
            }
            .navigationTitle("Write a review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Thanks for your review!", isPresented: $showSuccess) {
                Button("Done") {
                    onSubmitted()
                    dismiss()
                }
            } message: {
                Text("Your feedback helps other customers and \(braider.name).")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            if let first = braider.services.first {
                styleDone = first.name
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.md) {
            if braider.avatarUrl.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.18))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Review \(braider.name)")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Your honest feedback helps others.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer(minLength: 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Stars picker

    private var starsPicker: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("YOUR RATING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }

            HStack(spacing: Space.sm) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptic.medium()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            rating = i
                        }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundStyle(i <= rating ? Color.gold : Color.appSmoke)
                            .scaleEffect(i == rating ? 1.15 : 1)
                            .shadow(
                                color: i <= rating ? Color.gold.opacity(0.3) : .clear,
                                radius: i == rating ? 12 : 0
                            )
                    }
                    .buttonStyle(BMPressStyle(scale: 0.9))
                }
                Spacer()
            }

            Text(ratingLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gold)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .id(rating)
        }
        .padding(Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    private var ratingLabel: String {
        switch rating {
        case 5: return "Excellent — loved it"
        case 4: return "Very good"
        case 3: return "Good"
        case 2: return "Could be better"
        default: return "Not for me"
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Text block

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("YOUR REVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tell others about your experience — quality, timing, how you felt afterwards…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appSmoke)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appInk)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .frame(minHeight: 150)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appDivider, lineWidth: 1)
            )

            HStack {
                Text("\(text.count) characters")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appSmoke)
                Spacer()
                if text.trimmingCharacters(in: .whitespaces).count < 5 && !text.isEmpty {
                    Text("A few more words please")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.20), value: appeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Style block

    private var styleBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("WHICH SERVICE?")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }

            if braider.services.isEmpty {
                Text("No services listed")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appAsh)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(braider.services) { service in
                            Button {
                                Haptic.select()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                    styleDone = service.name
                                }
                            } label: {
                                Text(service.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(styleDone == service.name ? Color.appInkInverse : Color.appInk)
                                    .padding(.horizontal, Space.md)
                                    .frame(minHeight: 38)
                                    .padding(.vertical, 4)
                                    .background(styleDone == service.name ? Color.appInk : Color.appSurface, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            styleDone == service.name ? Color.clear : Color.appDivider,
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(
                                        color: styleDone == service.name ? Color.appInk.opacity(0.2) : .clear,
                                        radius: 8, y: 4
                                    )
                            }
                            .buttonStyle(BMPressStyle(scale: 0.97))
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.25), value: appeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Submit

    private var submitArea: some View {
        VStack(spacing: Space.sm) {
            if let hint = disabledHint {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                    Text(hint)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.appAsh)
                .transition(.opacity)
            }
            BMPrimaryButton(
                title: submitting ? "Submitting…" : "Post review",
                icon: "paperplane.fill",
                loading: submitting
            ) {
                submit()
            }
            .disabled(!canSubmit || submitting)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .padding(.top, Space.xs)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.30), value: appeared)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: canSubmit)
    }

    private func submit() {
        guard canSubmit else { return }
        let uid = session.uid
        guard !uid.isEmpty else {
            errorMessage = "You need to be signed in to review."
            return
        }
        submitting = true
        Haptic.press()

        let userName = session.displayName
            ?? FirebaseManager.shared.currentUser?.displayName
            ?? "Anonymous"
        let userAvatar = FirebaseManager.shared.currentUser?.avatarUrl ?? ""

        Task {
            do {
                try await FirebaseManager.shared.submitReview(
                    braiderId: braider.id,
                    userId: uid,
                    userName: userName,
                    userAvatar: userAvatar,
                    rating: Double(rating),
                    text: text.trimmingCharacters(in: .whitespaces),
                    styleDone: styleDone
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