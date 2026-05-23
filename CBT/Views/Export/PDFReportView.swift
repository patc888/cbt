import SwiftUI

struct PDFReportView: View {
    let payload: CBTDataExportPayload
    let userName: String = "CBT User" // Could be fetched from settings if available

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CBT Progress Report")
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundStyle(.accent)
                }
                
                Text("Generated on \(payload.exportedAt)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Divider()
            }
            
            // Mood Summary
            if !payload.moodEntries.isEmpty {
                SectionHeader(title: "Mood Summary", icon: "face.smiling")
                
                VStack(alignment: .leading, spacing: 10) {
                    let recentMoods = payload.moodEntries.suffix(10).reversed()
                    ForEach(recentMoods, id: \.id) { mood in
                        HStack {
                            Text(mood.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Score: \(mood.moodScore)/10")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            if let intensity = mood.intensity {
                                Text("Intensity: \(intensity)%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !mood.emotions.isEmpty {
                            Text(mood.emotions.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 10)
            }
            
            // Thought Records
            if !payload.thoughtRecords.isEmpty {
                SectionHeader(title: "Recent Thought Records", icon: "brain")
                
                VStack(alignment: .leading, spacing: 16) {
                    let recentThoughts = payload.thoughtRecords.suffix(5).reversed()
                    ForEach(recentThoughts, id: \.id) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.accent)
                            
                            ReportField(label: "Situation", content: record.situation)
                            ReportField(label: "Automatic Thought", content: record.automaticThought)
                            
                            if !record.distortions.isEmpty {
                                ReportField(label: "Cognitive Distortions", content: record.distortions.joined(separator: ", "))
                            }
                            
                            ReportField(label: "Balanced Thought", content: record.balancedThought)
                            
                            HStack {
                                Text("Intensity: \(record.intensityBefore)% → \(record.intensityAfter)%")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Exercises
            if !payload.exerciseCompletions.isEmpty {
                SectionHeader(title: "Exercise Completions", icon: "figure.mind.and.body")
                
                VStack(alignment: .leading, spacing: 8) {
                    let recentExercises = payload.exerciseCompletions.suffix(10).reversed()
                    ForEach(recentExercises, id: \.id) { completion in
                        HStack {
                            Text(completion.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(completion.exerciseID) // Ideally would be the localized title
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .padding(.leading, 10)
            }
            
            Spacer()
            
            // Footer
            VStack(alignment: .center, spacing: 4) {
                Divider()
                Text("CBT Application Progress Report - Confidentially Generated")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(40)
        .frame(width: 595, height: 842) // A4 size in points
        .background(Color.white)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.accent)
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
    }
}

private struct ReportField: View {
    let label: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }
}
