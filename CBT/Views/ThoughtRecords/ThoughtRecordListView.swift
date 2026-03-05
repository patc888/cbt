import SwiftUI
import SwiftData

struct ThoughtRecordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ThoughtRecord> { !$0.isDeleted },
        sort: \ThoughtRecord.createdAt,
        order: .reverse
    ) private var records: [ThoughtRecord]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingNewRecord = false
    
    var body: some View {
        ZStack {
            Theme.secondaryBackground.ignoresSafeArea()
            
            if records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.secondaryText)
                    Text("No thought records yet.")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("Capture and reframe your automatic thoughts.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        showingNewRecord = true
                    } label: {
                        Text("Add Thought Record")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primaryColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                ThoughtRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    softDelete(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("")
        .navigationDestination(for: ThoughtRecord.self) { record in
            ThoughtRecordDetailView(record: record)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button {
                    HapticManager.shared.lightImpact()
                    showingNewRecord = true
                } label: {
                    Text("+ Thought")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.secondaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0), radius: colorScheme == .dark ? 2 : 0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingNewRecord) {
            NewThoughtRecordFlowView()
        }
    }
    
    private func softDelete(_ record: ThoughtRecord) {
        do {
            try modelContext.cbtStore.softDelete(item: record)
        } catch {
            print("Failed to delete record: \(error)")
        }
    }
}

fileprivate struct ThoughtRecordRow: View {
    let record: ThoughtRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.secondaryColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.secondaryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Thought Record")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text("\(record.intensityBefore)→\(record.intensityAfter)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.secondaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !record.situation.isEmpty {
                Text(record.situation)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
            }

            if !record.automaticThought.isEmpty {
                Text("“\(record.automaticThought)”")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            let tags = record.emotions + record.distortions
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(tags.prefix(5)), id: \.self) { tag in
                            TagChip(title: tag)
                        }
                        if tags.count > 5 {
                            TagChip(title: "+\(tags.count - 5)")
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
