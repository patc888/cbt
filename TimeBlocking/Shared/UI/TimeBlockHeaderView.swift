import SwiftUI

struct TimeBlockHeaderView: View {
    let block: TimeBlock
    let accentColor: Color
    let categoryIcon: String
    let timeRangeText: String
    let conflictSummary: ScheduleBlockConflictSummary?
    let supportsDrag: Bool
    let isDragging: Bool
    let fillProgress: CGFloat
    let handleComplete: @MainActor () -> Void
    let dragHandle: AnyView
    
    var body: some View {
        HStack(spacing: 16) {
            iconTile
            titleAndCategory
            timeAndConflictInfo
            Spacer(minLength: 0)
            statusControls
        }
    }
    
    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentColor.opacity(block.status == .completed ? 0.6 : 1.0))
                .frame(width: 64, height: 64)
                .adaptiveShadow(color: accentColor.opacity(block.status == .completed ? 0 : 0.4), radius: 12, x: 0, y: 6)
            
            Image(systemName: categoryIcon)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .opacity(block.status == .completed ? 0.6 : 1.0)
                .adaptiveShadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }

    private var titleAndCategory: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(block.status == .completed || fillProgress > 0.8 ? .secondary : .primary)
                    .lineLimit(1)
                    .strikethrough(block.status == .completed || fillProgress > 0.8)
                    .opacity(block.status == .completed || fillProgress > 0.8 ? 0.6 : 1.0)
                
                if block.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                }
            }
            
            Text(block.category.title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(accentColor.opacity(0.8))
        }
    }

    private var timeAndConflictInfo: some View {
        HStack(spacing: 6) {
            Text(timeRangeText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            
            if let conflictSummary {
                Text("•")
                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                Text(conflictSummary.badgeText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusControls: some View {
        HStack(spacing: 12) {
            if supportsDrag && block.status != .completed {
                dragHandle
            }

            Button {
                handleComplete()
            } label: {
                statusIcon
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if block.status == .completed || fillProgress > 0.9 {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.green)
        } else {
            Circle()
                .stroke(accentColor.opacity(0.3), lineWidth: 3)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(accentColor.opacity(0.7))
                )
        }
    }
}
