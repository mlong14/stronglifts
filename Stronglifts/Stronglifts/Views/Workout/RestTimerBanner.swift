import SwiftUI

struct RestTimerBanner: View {
    let secondsRemaining: Int
    let onSkip: () -> Void

    private var minutes: Int { secondsRemaining / 60 }
    private var seconds: Int { secondsRemaining % 60 }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.tint)

            Text("Rest")
                .font(.headline)

            Text(String(format: "%d:%02d", minutes, seconds))
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(.tint)

            Spacer()

            Button("Skip", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray5))
    }
}
