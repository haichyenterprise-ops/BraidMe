import SwiftUI

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
                        .font(.bmUI(15, weight: .medium))
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
            appeared = true
            if let first = braider.services.first {
                styleDone = first.name
            }
        }
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            BMAvatar(url: braider.avatarUrl, size: 52, initials: initials)
            VStack(alignment: .leading, spacing: 3) {
                Text("Review \(braider.name)")
                    .font(.bmDisplay(20, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Your honest feedback helps others.")
                    .font(.bmUI(13))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer(minLength: 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animate(Motion.reveal, value: appeared)
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    private var starsPicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Your rating")
            HStack(spacing: Space.xs) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptic.select()
                        withAnimation(Motion.press) { rating = i }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.bmUI(30))
                            .foregroundStyle(i <= rating ? Color.appAccent : Color.appSmoke)
                            .scaleEffect(i == rating ? 1.1 : 1)
                            .animation(Motion.press, value: rating)
                    }
                    .buttonStyle(BMPressStyle(scale: 0.94))
                }
                Spacer()
            }
            Text(ratingLabel)
                .font(.bmUI(13, weight: .medium))
                .foregroundStyle(Color.appAccent)
        }
        .padding(Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animate(Motion.reveal.delay(0.05), value: appeared)
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

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            BMSectionLabel(text: "Your review")
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tell others about your experience — quality, timing, how you felt afterwards…")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.appSmoke)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.bmUI(15))
                    .foregroundStyle(Color.appInk)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .frame(minHeight: 140)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
            HStack {
                Text("\(text.count) characters")
                    .font(.bmUI(11))
                    .foregroundStyle(Color.appSmoke)
                Spacer()
                if text.trimmingCharacters(in: .whitespaces).count < 5 && !text.isEmpty {
                    Text("A few more words please")
                        .font(.bmUI(11, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animate(Motion.reveal.delay(0.10), value: appeared)
    }

    private var styleBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Which service?")
            if braider.services.isEmpty {
                Text("No services listed")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(braider.services) { service in
                            Button {
                                Haptic.select()
                                withAnimation(Motion.press) { styleDone = service.name }
                            } label: {
                                Text(service.name)
                                    .font(.bmUI(13, weight: .semibold))
                                    .foregroundStyle(styleDone == service.name ? Color.appInkInverse : Color.appInk)
                                    .padding(.horizontal, Space.md)
                                    .frame(minHeight: 34)
                                    .padding(.vertical, 4)
                                    .background(styleDone == service.name ? Color.appInk : Color.appSurface, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            styleDone == service.name ? Color.clear : Color.appDivider,
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(BMPressStyle(scale: 0.97))
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animate(Motion.reveal.delay(0.15), value: appeared)
    }

    private var submitArea: some View {
        VStack(spacing: Space.xs) {
            if let hint = disabledHint {
                Text(hint)
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appAsh)
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