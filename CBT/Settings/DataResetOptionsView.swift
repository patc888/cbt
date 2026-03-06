import SwiftUI

struct DataResetOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var showingLocalConfirm = false
    @State private var showingCloudSheet = false
    @State private var cloudConfirmText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reset Options")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.primaryColor)
                        
                        Text("You can choose to reset data only on this device, or completely delete your synced data from iCloud as well.")
                            .font(.body)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Option A
                    SettingsSection(title: "Reset This Device") {
                        Button {
                            HapticManager.shared.mediumImpact()
                            showingLocalConfirm = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reset This Device")
                                    .font(.headline)
                                    .foregroundStyle(Theme.errorRed)
                                
                                Text("Clears local data, preferences, and notifications on this device only. If iCloud sync is enabled, your data remains in the cloud and will re-sync back to this device the next time you open the app.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Option B
                    SettingsSection(title: "Reset Everywhere") {
                        Button {
                            HapticManager.shared.mediumImpact()
                            cloudConfirmText = ""
                            showingCloudSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reset Everywhere (Delete iCloud Data)")
                                    .font(.headline)
                                    .foregroundStyle(Theme.errorRed)
                                
                                Text("Permanently deletes your data from this device AND erases all synced records from your private iCloud. This affects all your devices. This action is permanent and cannot be undone.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Reset Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if isProcessing {
                ProgressView("Deleting Data...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .alert("Reset This Device?", isPresented: $showingLocalConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Local Data", role: .destructive) {
                performLocalWipe()
            }
        } message: {
            Text("This will delete all local app data and preferences. If iCloud sync is enabled, it may download again.")
        }
        .sheet(isPresented: $showingCloudSheet) {
            NavigationStack {
                Form {
                    Section {
                        Text("This will permanently delete all your CBT data from this device and iCloud. This action cannot be undone and will affect all your synchronized devices.")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                        
                        Text("Please type DELETE below to confirm.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        
                        TextField("Type DELETE to confirm", text: $cloudConfirmText)
                        #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        #endif
                    }
                    
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            Task { await performGlobalWipe() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Permanently Delete Data")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(cloudConfirmText.uppercased() != "DELETE")
                    }
                }
                .navigationTitle("Confirm iCloud Deletion")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingCloudSheet = false }
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
    }
    
    private func performLocalWipe() {
        DataResetManager.shared.performLocalWipe()
        dismiss()
    }
    
    private func performGlobalWipe() async {
        isProcessing = true
        errorMessage = nil
        do {
            try await DataResetManager.shared.performGlobalWipe()
            await MainActor.run {
                isProcessing = false
                showingCloudSheet = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to delete iCloud data: \(error.localizedDescription)"
            }
        }
    }
}
