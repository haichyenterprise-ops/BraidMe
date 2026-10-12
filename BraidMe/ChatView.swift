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
        ZStack {
            AuroraBackground(intensity: 0.35)

            VStack(spacing: 0) {
                topBar
                messagesScroll
                inputBar
            }
        }
        .onAppear {
            startObserving()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: Space.sm) {
            BMAvatar(url: "", size: 46, ringed: true, initials: bmInitials(booking.braiderName))
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.braiderName)
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(Color.bmGood).frame(width: 6, height: 6)
                    Text(booking.style)
                        .font(.bmUI(13, weight: .medium))
                        .foregroundStyle(Color.bmTextDim)
                        .lineLimit(1)
                }
            }
            Spacer()
            BMIconButton(icon: "xmark", size: 40, iconSize: 13) { dismiss() }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    headerCard

                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedMessages, id: \.date) { group in
                            dateSeparator(group.date)
                            ForEach(group.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                                    .transition(
                                        .scale(scale: 0.88, anchor: msg.senderId == currentUserId ? .bottomTrailing : .bottomLeading)
                                            .combined(with: .opacity)
                                    )
                            }
                        }
                    }

                    Color.clear.frame(height: Space.xs)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
                .animation(Motion.sheet, value: messages.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(Motion.sheet) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            BMOrb(icon: "bubble.left.and.bubble.right", size: 78)
            Text("Say hello")
                .font(.bmDisplay(22, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Text("Ask \(booking.braiderName) about timing, prep or anything else.")
                .font(.bmUI(13))
                .foregroundStyle(Color.bmTextDim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, Space.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var headerCard: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "calendar")
                .font(.bmUI(13, weight: .bold))
                .foregroundStyle(Color.bmGilt)
                .frame(width: 32, height: 32)
                .background(Color.bmGilt.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.style)
                    .font(.bmUI(14, weight: .bold))
                    .foregroundStyle(Color.bmText)
                Text("\(booking.date.formatted(date: .abbreviated, time: .omitted)) at \(booking.time)")
                    .font(.bmUI(12))
                    .foregroundStyle(Color.bmTextDim)
            }
            Spacer()
        }
        .padding(Space.sm)
        .bmGlass(radius: Radius.button)
        .padding(.bottom, Space.xs)
    }

    private func dateSeparator(_ date: Date) -> some View {
        Text(dateLabel(date))
            .font(.bmUI(12, weight: .semibold))
            .foregroundStyle(Color.bmTextDim)
            .padding(.horizontal, Space.sm)
            .frame(height: 26)
            .background(Color.white.opacity(0.07), in: Capsule())
            .padding(.vertical, Space.xs)
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
            if isMine { Spacer(minLength: 56) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(msg.text)
                    .font(.bmUI(16))
                    .foregroundStyle(isMine ? Color.bmOnGilt : Color.bmText)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 10)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: isMine ? 20 : 6,
                            bottomTrailingRadius: isMine ? 6 : 20,
                            topTrailingRadius: 20,
                            style: .continuous
                        )
                        .fill(isMine ? AnyShapeStyle(LinearGradient.bmGiltGradient) : AnyShapeStyle(Color.bmSurface))
                    }
                    .overlay {
                        if !isMine {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 6,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 20,
                                style: .continuous
                            )
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                        }
                    }
                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.bmUI(11))
                    .foregroundStyle(Color.bmTextFaint)
                    .padding(.horizontal, 4)
            }
            if !isMine { Spacer(minLength: 56) }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Space.xs) {
            TextField(
                "",
                text: $draft,
                prompt: Text("Message…").foregroundColor(Color.bmTextFaint),
                axis: .vertical
            )
            .font(.bmUI(16))
            .foregroundStyle(Color.bmText)
            .tint(Color.bmGilt)
            .lineLimit(1...4)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 13)
            .bmGlass(radius: 26)
            .focused($inputFocused)

            Button(action: sendMessage) {
                ZStack {
                    if sending {
                        BMSpinner(color: Color.bmOnGilt, size: 16)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.bmUI(17, weight: .heavy))
                            .foregroundStyle(canSend ? Color.bmOnGilt : Color.bmTextFaint)
                    }
                }
                .frame(width: 50, height: 50)
                .background {
                    if canSend {
                        Circle().fill(LinearGradient.bmGiltGradient)
                    } else {
                        Circle().fill(Color.white.opacity(0.08))
                    }
                }
                .scaleEffect(canSend ? 1 : 0.92)
                .animation(Motion.pop, value: canSend)
            }
            .disabled(!canSend || sending)
            .buttonStyle(BMIconPressStyle())
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.sm)
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
