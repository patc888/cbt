import SwiftUI
import SwiftData

struct ActivityCompletionView: View {
    @Bindable var activity: PlannedActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var actualEnjoyment = 5.0
    @State private var notes = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.title)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                            Text("Scheduled for \(activity.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top)
                        
                        Divider()
                        
                        sectionTitle("The Result")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("How much did you ACTUALLY enjoy it?")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text("\(Int(actualEnjoyment))/10")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                            
                            Slider(value: $actualEnjoyment, in: 0...10, step: 1)
                                .tint(themeManager.selectedColor)
                            
                            HStack {
                                Text("Not at all")
                                Spacer()
                                Text("Loved it")
                            }
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Predicted: \(activity.predictedEnjoyment)/10")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.secondaryText)
                            
                            if Int(actualEnjoyment) > activity.predictedEnjoyment {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Evidence: You enjoyed this \(Int(actualEnjoyment) - activity.predictedEnjoyment) points more than your brain predicted.")
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Theme.successGreen)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .background(Theme.successGreen.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        
                        sectionTitle("Notes (Optional)")
                        TextField("Any reflections?", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .padding()
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Reflect on Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        completeActivity()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Could Not Save Reflection", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
    
    private func completeActivity() {
        activity.actualEnjoyment = PlannedActivity.clampRating(Int(actualEnjoyment))
        activity.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.isCompleted = true
        activity.completedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
