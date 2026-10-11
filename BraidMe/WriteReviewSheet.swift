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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        starsPicker
                        textBlock
                        styleBlock
                        submitButton
                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Write a review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
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
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            // Prefill with first service name
            if let first = braider.services.first {
                styleDone = first.name
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                Circle()
                    .stroke(AppTheme.accent, lineWidth: 2)
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Review \(braider.name)")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Your honest feedback helps others.")
                    .font(AppTheme.sans(13))
                    .foregroundColor(AppTheme.slate)
            }

            Spacer(minLength: 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Stars

    private var starsPicker: some View {
        VStack(spacing: 14) {
            Text("Your rating")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptics.medium()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            rating = i
                        }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 34))
                            .foregroundColor(i <= rating ? AppTheme.gold : AppTheme.ash)
                            .scaleEffect(i == rating ? 1.15 : 1)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: rating)
                    }
                    .buttonStyle(SoftPress())
                }
                Spacer()
            }

            Text(ratingLabel)
                .font(AppTheme.sans(13, weight: .medium))
                .foregroundColor(AppTheme.accentDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.2), value: rating)
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
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

    // MARK: - Text

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR REVIEW")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tell others about your experience — quality, timing, how you felt afterwards…")
                        .font(AppTheme.sans(15))
                        .foregroundColor(AppTheme.stone.opacity(0.7))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 140)
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )

            HStack {
                Text("\(text.count) characters")
                    .font(AppTheme.sans(11))
                    .foregroundColor(AppTheme.stone)
                Spacer()
                if text.trimmingCharacters(in: .whitespaces).count < 5 && !text.isEmpty {
                    Text("A few more words please")
                        .font(AppTheme.sans(11, weight: .medium))
                        .foregroundColor(AppTheme.warn)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Style

    private var styleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHICH SERVICE?")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)

            if braider.services.isEmpty {
                Text("No services listed")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.stone)
                    .italic()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(braider.services) { service in
                        Button {
                            Haptics.select()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                styleDone = service.name
                            }
                        } label: {
                            Text(service.name)
                                .font(AppTheme.sans(13, weight: .semibold))
                                .foregroundColor(styleDone == service.name ? .white : AppTheme.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(styleDone == service.name ? AppTheme.ink : AppTheme.snow, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            styleDone == service.name ? Color.clear : AppTheme.hairline,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(SoftPress())
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Submit

    private var submitButton: some View {
        PrimaryButton(
            title: submitting ? "Submitting…" : "Post review",
            icon: "paperplane.fill",
            loading: submitting
        ) {
            submit()
        }
        .disabled(!canSubmit || submitting)
        .opacity(canSubmit ? 1 : 0.4)
        .padding(.top, 8)
    }

    // MARK: - Action

    private func submit() {
        guard canSubmit else { return }
        let uid = session.uid
        guard !uid.isEmpty else {
            errorMessage = "You need to be signed in to review."
            return
        }

        submitting = true
        Haptics.medium()

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
                    Haptics.success()
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    submitting = false
                    errorMessage = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }
}