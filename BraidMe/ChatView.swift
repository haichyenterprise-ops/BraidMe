import SwiftUI
import FirebaseDatabase

struct ChatView: View {
    let booking: Booking
    let currentUserId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var fb = FirebaseManager.shared

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var observerHandle: DatabaseHandle?
    @State private var sending = false

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
            .navigationTitle(booking.braiderName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                }
            }
        }
        .onAppear {
            startObserving()
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

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: Space.xs) {
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
                .padding(.top, Space.sm)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(Motion.press) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.bmUI(28, weight: .light))
                .foregroundStyle(Color.appSmoke)
            Text("Start the conversation")
                .font(.bmUI(14, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("Ask \(booking.braiderName) about timing, prep, or anything else.")
                .font(.bmUI(12))
                .foregroundStyle(Color.appAsh)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, Space.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }

    private var headerCard: some View {
        VStack(spacing: 4) {
            Text("Conversation about")
                .font(.bmUI(11, weight: .medium))
                .foregroundStyle(Color.appSmoke)
            Text(booking.style)
                .font(.bmUI(14, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.time)")
                .font(.bmUI(12))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.md)
        .background(Color.appAccentTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.bottom, Space.sm)
    }

    private func dateSeparator(_ date: Date) -> some View {
        HStack(spacing: Space.sm) {
            BMDivider()
            Text(dateLabel(date))
                .font(.bmUI(11, weight: .medium))
                .foregroundStyle(Color.appSmoke)
                .fixedSize()
            BMDivider()
        }
        .padding(.vertical, Space.sm)
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
                    .font(.bmUI(15))
                    .foregroundStyle(isMine ? Color.appInkInverse : Color.appInk)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm)
                    .background(isMine ? Color.appInk : Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .stroke(isMine ? Color.clear : Color.appDivider, lineWidth: isMine ? 0 : 0.5)
                    )
                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.bmUI(10))
                    .foregroundStyle(Color.appSmoke)
                    .padding(.horizontal, Space.xxs)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: Space.xs) {
            TextField("Message…", text: $draft, axis: .vertical)
                .font(.bmUI(15))
                .lineLimit(1...4)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(Color.appDivider, lineWidth: 0.5)
                )
                .focused($inputFocused)

            Button(action: sendMessage) {
                ZStack {
                    if sending {
                        ProgressView().tint(Color.appInkInverse).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.bmUI(15, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                }
                .frame(width: 44, height: 44)
                .background(canSend ? Color.appInk : Color.appSmoke, in: Circle())
            }
            .disabled(!canSend || sending)
            .buttonStyle(BMIconPressStyle())
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) { BMDivider() }
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
        Haptic.select()
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