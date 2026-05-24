import SwiftUI
import SwiftData

struct AddActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Nourishing"
    @State private var date = Date()
    @State private var predictedEnjoyment = 5.0
    @State private var errorMessage: String?
    
    private let columns = [GridItem(.adaptive(minimum: 116), spacing: 8)]
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionTitle("What are you planning?")
                        TextField("Activity Title", text: $title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .padding()
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        sectionTitle("Category")
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(PlannedActivity.categories, id: \.self) { cat in
                                Button {
                                    category = cat
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    Text(cat)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .padding(.horizontal, 16)
                                        .background(category == cat ? themeManager.selectedColor : Theme.tertiaryBackground)
                                        .foregroundStyle(category == cat ? .white : Theme.primaryText)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        sectionTitle("When?")
                        DatePicker("", selection: $date)
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        sectionTitle("Predicted Enjoyment")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("How much will you enjoy this?")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Spacer()
                                Text("\(Int(predictedEnjoyment))/10")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                            
                            Slider(value: $predictedEnjoyment, in: 0...10, step: 1)
                                .tint(themeManager.selectedColor)
                            
                            HStack {
                                Text("Not at all")
                                Spacer()
                                Text("A lot")
                            }
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        Text("Note: Depression often makes us predict things will be 'meh' or exhausting. Be honest about your current low prediction—we'll test it later.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        saveActivity()
                    }
                    .disabled(!canSave)
                    .fontWeight(.bold)
                }
            }
            .alert("Could Not Schedule Activity", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
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
    
    private func saveActivity() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let newActivity = PlannedActivity(
            title: trimmedTitle,
            activityDescription: description,
            category: category,
            scheduledDate: date,
            predictedEnjoyment: Int(predictedEnjoyment)
        )
        modelContext.insert(newActivity)
        do {
            try modelContext.save()
            Task { @MainActor in
                await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
