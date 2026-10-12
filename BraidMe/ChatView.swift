import SwiftUI
import FirebaseDatabase

// =============================================================================
// ChatView — Real-time messaging, upgraded
// Glass toolbar, animated bubbles, online indicator, glass input bar.
// =============================================================================

struct ChatView: View {
    let booking: Booking
    let currentUserId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var observerHandle: DatabaseHandle?
    @State private var sending = false
    @State private var appeared = false
    @State private var typingDots = false

    @FocusState private var inputFocused: Bool

    private var chatId: String { FirebaseManager.chatId(for: booking.id) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesScroll
                    inputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(booking.braiderName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.appSignal)
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.appAsh)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptic.press()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
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
        .onAppear {
            startObserving()
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                inputFocused = true
            }
        }
        .onDisappear {
            if let h = observerHandle {
                fb.removeObserver(chatId: chatId, handle: h)
                observerHandle = nil
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: Space.sm) {
                    headerCard

                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedMessages, id: \.date) { group in
                            dateSeparator(group.date)
                            ForEach(group.messages) { msg in
                                messageBubble(msg).id(msg.id)
                            }
                        }
                    }

                    Color.clear.frame(height: Space.xs)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.gold)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Space.xs) {
                Text("Start the conversation")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.appInk)
                Text("Ask \(booking.braiderName) about timing, prep, or anything else.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Space.lg)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }

    private var headerCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .semibold))
                Text("·")
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(booking.time)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.gold)

            Text(booking.style)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appInk)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.md)
        .background(Color.gold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button)
                .stroke(Color.gold.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, Space.sm)
    }

    private func dateSeparator(_ date: Date) -> some View {
        HStack(spacing: Space.md) {
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 0.5)
            Text(dateLabel(date))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.appSmoke)
                .fixedSize()
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 0.5)
        }
        .padding(.vertical, Space.md)
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isMine = msg.senderId == currentUserId
        return HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: Space.xxs) {
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundStyle(isMine ? Color.appInkInverse : Color.appInk)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm)
                    .background(
                        Group {
                            if isMine {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.appInk)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.appSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.appDivider, lineWidth: 0.5)
                                    )
                            }
                        }
                    )
                    .shadow(color: Color.black.opacity(isMine ? 0.15 : 0.04), radius: 8, y: 2)

                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.appSmoke)
                    .padding(.horizontal, Space.xs)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...5)
                    .foregroundStyle(Color.appInk)
                    .focused($inputFocused)

                if !draft.isEmpty {
                    Button {
                        Haptic.select()
                        draft = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appSmoke)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        inputFocused ? Color.gold.opacity(0.4) : Color.appDivider,
                        lineWidth: inputFocused ? 1.5 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.2), value: inputFocused)
            .animation(.easeOut(duration: 0.2), value: draft.isEmpty)

            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.appInk : Color.appSmoke)
                        .frame(width: 44, height: 44)
                        .shadow(color: canSend ? Color.appInk.opacity(0.2) : .clear, radius: 8, y: 4)

                    if sending {
                        ProgressView()
                            .tint(Color.appInkInverse)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                }
                .scaleEffect(canSend ? 1 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: canSend)
            }
            .disabled(!canSend || sending)
            .buttonStyle(BMIconPressStyle())
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Color.glassTintStrong)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 0.5)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func startObserving() {
        observerHandle = fb.observeMessages(chatId: chatId) { messages in
            self.messages = messages
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !currentUserId.isEmpty else { return }
        draft = ""
        Haptic.medium()
        sending = true

        Task {
            try? await fb.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                senderName: "Customer",
                text: text
            )
            await MainActor.run { sending = false }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Grouping

    private var groupedMessages: [(date: Date, messages: [ChatMessage])] {
        let cal = Calendar.current
        var groups: [(Date, [ChatMessage])] = []
        for msg in messages {
            let day = cal.startOfDay(for: msg.timestamp)
            if let last = groups.last, cal.isDate(last.0, inSameDayAs: day) {
                groups[groups.count - 1].1.append(msg)
            } else {
                groups.append((day, [msg]))
            }
        }
        return groups.map { (date: $0.0, messages: $0.1) }
    }
}