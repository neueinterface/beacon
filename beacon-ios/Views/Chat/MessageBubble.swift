import SwiftUI

struct MessageBubble: View {
    enum Role {
        case user
        case assistant
    }

    let text: String
    let role: Role

    var body: some View {
        HStack {
            if role == .assistant {
                assistantText
                Spacer(minLength: 56)
            } else {
                Spacer(minLength: 56)
                userBubble
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var assistantText: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
    }

    private var userBubble: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(UIColor.systemGray6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(text: "Hello! This is a placeholder response from the model.", role: .assistant)
        MessageBubble(text: "Great, can you explain local inference in simple terms?", role: .user)
    }
    .padding()
    .background(Color.white)
}
