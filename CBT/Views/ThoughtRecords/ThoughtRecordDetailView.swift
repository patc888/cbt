import SwiftUI
import SwiftData

struct ThoughtRecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: ThoughtRecord
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header (Date and Intentsity)
                HStack(alignment: .center) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    
                    HStack(spacing: 8) {
                        IntensityBadge(title: "Before", intensity: record.intensityBefore)
                        IntensityBadge(title: "After", intensity: record.intensityAfter)
                    }
                }
                
                // Content
                DetailSection(title: "Situation") {
                    Text(record.situation)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Automatic Thought") {
                    Text("“\(record.automaticThought)”")
                        .font(.body)
                        .italic()
                        .foregroundStyle(Theme.primaryText)
                }
                
                // Tags
                let tags = record.emotions + record.distortions
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emotions & Distortions")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(title: tag)
                            }
                        }
                    }
                }
                
                DetailSection(title: "Evidence For") {
                    Text(record.evidenceFor)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Evidence Against") {
                    Text(record.evidenceAgainst)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Balanced Thought") {
                    Text(record.balancedThought)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
        .background(ThemedBackground().ignoresSafeArea())
        .navigationTitle("Thought Record Detail")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .confirmationDialog(
            "Delete Thought Record?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func deleteRecord() {
        do {
            try modelContext.cbtStore.softDelete(item: record)
            dismiss()
        } catch {
            print("Failed to delete record: \(error)")
        }
    }
}

fileprivate struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            content
                .padding(.horizontal, 4)
        }
    }
}

fileprivate struct IntensityBadge: View {
    let title: String
    let intensity: Int
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
            Text("\(intensity)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.toggleBackgroundColor(for: .light))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// A simple FlowLayout for displaying tags
fileprivate struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return size(for: rows, proposal: proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y: CGFloat = bounds.minY
        
        for row in rows {
            var x: CGFloat = bounds.minX
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            
            for index in row {
                let view = subviews[index]
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let width = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentRowWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width > width, !rows[rows.count - 1].isEmpty {
                rows.append([index])
                currentRowWidth = size.width + spacing
            } else {
                rows[rows.count - 1].append(index)
                currentRowWidth += size.width + spacing
            }
        }
        return rows
    }
    
    private func size(for rows: [[Int]], proposal: ProposedViewSize) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        
        for row in rows {
            height += rowHeight(for: row, proposal: proposal)
        }
        
        height += CGFloat(max(0, rows.count - 1)) * spacing
        
        return CGSize(width: width, height: height)
    }
    
    private func rowHeight(for row: [Int], proposal: ProposedViewSize) -> CGFloat {
        // Just approximation, as height for subview can be accessed fully in layout 
        // This simple layout ignores height variation, assuming all chips have same height
        return 30
    }
}
