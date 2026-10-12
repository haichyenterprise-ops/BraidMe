import SwiftUI

// =============================================================================
// MARK: - Review row
// =============================================================================

struct SheetReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: review.userAvatar, size: 42, initials: bmInitials(review.userName))
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.userName)
                        .font(.bmUI(15, weight: .bold))
                        .foregroundStyle(Color.bmText)
                        .lineLimit(1)
                    HStack(spacing: Space.xs) {
                        BMStars(rating: review.rating, size: 10, spacing: 1)
                        Text(review.dateString)
                            .font(.bmUI(12))
                            .foregroundStyle(Color.bmTextDim)
                    }
                }
                Spacer(minLength: 0)
            }

            Text(review.text)
                .font(.bmUI(15))
                .foregroundStyle(Color.bmText.opacity(0.88))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.xs) {
                if !review.styleDone.isEmpty {
                    BMTag(text: review.styleDone, icon: "scissors")
                }
                Spacer(minLength: 0)
                if review.helpful > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.bmUI(10, weight: .bold))
                        Text("\(review.helpful) found this helpful")
                            .font(.bmUI(11, weight: .medium))
                    }
                    .foregroundStyle(Color.bmTextDim)
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

