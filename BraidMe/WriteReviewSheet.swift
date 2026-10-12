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
        ZStack {
            AuroraBackground(intensity: 0.45)

            VStack(spacing: 0) {
                BMSheetBar(title: "Write a review", subtitle: "Help others choose with confidence") {
                    dismiss()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        header
                        starsPicker
                        textBlock
                        styleBlock
                        submitArea
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .alert("Couldn't post review", isPresented: Binding(
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
        .onAppear {
            appeared = true
            if let first = braider.services.first {
                styleDone = first.name
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.md) {
            BMAvatar(url: braider.avatarUrl, size: 56, ringed: true, initials: bmInitials(braider.name))
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("How was \(braider.name)?")
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("Your honest feedback helps others.")
                    .font(.bmUI(13))
                    .foregroundStyle(Color.bmTextDim)
            }
            Spacer(minLength: 0)
        }
        .reveal(appeared, offset: 14)
    }

    // MARK: - Stars

    private var starsPicker: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.xs) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptic.select()
                        withAnimation(Motion.pop) { rating = i }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(
                                i <= rating
                                    ? AnyShapeStyle(LinearGradient.bmGiltGradient)
                                    : AnyShapeStyle(Color.white.opacity(0.22))
                            )
                            .scaleEffect(i <= rating ? 1.0 : 0.88)
                            .symbolEffect(.bounce, value: rating)
                            .shadow(color: i <= rating ? Color.bmGilt.opacity(0.45) : Color.clear, radius: 10)
                            .animation(Motion.pop.delay(Double(i) * 0.02), value: rating)
                    }
                    .buttonStyle(BMPressStyle(scale: 0.9, dim: 0))
                }
            }

            Text(ratingLabel)
                .font(.bmDisplay(18, weight: .medium))
                .foregroundStyle(Color.bmGilt)
                .id(rating)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .bmCard(radius: Radius.card)
        .animation(Motion.sheet, value: rating)
        .reveal(appeared, delay: 0.06, offset: 18, blur: 0)
    }

    private var ratingLabel: String {
        switch rating {
        case 5: return "Excellent, loved it"
        case 4: return "Very good"
        case 3: return "Good"
        case 2: return "Could be better"
        default: return "Not for me"
        }
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            BMSectionLabel(text: "Your review")
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tell others about your experience: quality, timing, how you felt afterwards…")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.bmTextFaint)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.bmUI(15))
                    .foregroundStyle(Color.bmText)
                    .tint(Color.bmGilt)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .frame(minHeight: 150)
            }
            .background(Color.bmSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(
                        text.isEmpty ? Color.white.opacity(0.1) : Color.bmGilt.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .animation(Motion.subtle, value: text.isEmpty)

            HStack {
                Text("\(text.count) characters")
                    .font(.bmUI(12))
                    .foregroundStyle(Color.bmTextFaint)
                Spacer()
                if text.trimmingCharacters(in: .whitespaces).count < 5 && !text.isEmpty {
                    Text("A few more words please")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.bmGilt)
                }
            }
        }
        .reveal(appeared, delay: 0.12, offset: 18, blur: 0)
    }

    // MARK: - Service

    private var styleBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Which service?")
            if braider.services.isEmpty {
                Text("No services listed")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.bmTextDim)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(braider.services) { service in
                            BMChip(title: service.name, isSelected: styleDone == service.name) {
                                withAnimation(Motion.press) { styleDone = service.name }
                            }
                        }
                    }
                }
            }
        }
        .reveal(appeared, delay: 0.18, offset: 18, blur: 0)
    }

    // MARK: - Submit

    private var submitArea: some View {
        VStack(spacing: Space.xs) {
            if let hint = disabledHint {
                Text(hint)
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
            }
            BMPrimaryButton(
                title: submitting ? "Posting…" : "Post review",
                icon: submitting ? nil : "paperplane.fill",
                loading: submitting
            ) {
                submit()
            }
            .disabled(!canSubmit || submitting)
            .opacity(canSubmit ? 1 : 0.45)
            .animation(Motion.subtle, value: canSubmit)
        }
        .padding(.top, Space.xs)
        .reveal(appeared, delay: 0.24, offset: 18, blur: 0)
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
