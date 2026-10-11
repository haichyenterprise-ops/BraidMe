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
    @State private var appeared = false

    @FocusState private var inputFocused: Bool

    private var chatId: String {
        FirebaseManager.chatId(for: booking.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

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
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            startObserving()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                inputFocused = true
            }
        }
        .onDisappear {
            if let handle = observerHandle {
                fb.removeObserver(chatId: chatId, handle: handle)
                observerHandle = nil
            }
        }
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    headerCard

                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text("Conversation about")
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundColor(AppTheme.stone)
            Text(booking.style)
                .font(AppTheme.sans(14, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text("\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.time)")
                .font(AppTheme.sans(12))
                .foregroundColor(AppTheme.slate)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.mist)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 8)
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isMine = msg.senderId == currentUserId
        return HStack {
            if isMine { Spacer(minLength: 60) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(msg.text)
                    .font(AppTheme.sans(15))
                    .foregroundColor(isMine ? .white : AppTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isMine
                            ? AnyView(AppTheme.inkGradient)
                            : AnyView(AppTheme.snow)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isMine ? Color.clear : AppTheme.hairline, lineWidth: isMine ? 0 : 0.5)
                    )

                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(AppTheme.sans(10))
                    .foregroundColor(AppTheme.stone)
                    .padding(.horizontal, 4)
            }

            if !isMine { Spacer(minLength: 60) }
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $draft, axis: .vertical)
                .font(AppTheme.sans(15))
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.snow)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.hairline, lineWidth: 0.5)
                )
                .focused($inputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        canSend
                            ? AnyView(AppTheme.inkGradient)
                            : AnyView(AppTheme.stone)
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.ink.opacity(0.2), radius: 8, y: 3)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func startObserving() {
        observerHandle = fb.observeMessages(chatId: chatId) { messages in
            self.messages = messages
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !currentUserId.isEmpty else { return }

        draft = ""
        Haptics.soft()

        Task {
            try? await fb.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                senderName: "Customer",
                text: text
            )
        }
    }
}