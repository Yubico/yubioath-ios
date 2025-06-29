import SwiftUI

struct FIDOCredentialsView: View {
    
    @StateObject var model = FIDOCredentialsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State var presentErrorAlert = false
    @State var error: Error? = nil
    @State var selectedCredentialForDeletion: FIDOCredential? = nil
    @State var presentDeleteConfirmation = false
    
    func areButtonsDisabled() -> Bool {
        model.state == .unknown || model.state.isError() || model.isProcessing
    }

    var body: some View {
        VStack {
            if model.isProcessing {
                ProgressView("Loading credentials...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.state == .loaded {
                if model.credentials.isEmpty {
                    SettingsView(image: Image(systemName: "person.badge.key"), imageColor: Color(.systemBlue)) {
                        Text("Manage Passkeys").font(.title2).bold()
                        Text("No passkeys found on this YubiKey.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    } buttons: {
                        // 空の状態ではボタンを表示しない
                    }
                } else {
                    List {
                        ForEach(model.credentials) { credential in
                            CredentialRowView(credential: credential) {
                                selectedCredentialForDeletion = credential
                                presentDeleteConfirmation = true
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
//            } else if model.state == .error {
//                SettingsView(image: Image(systemName: "exclamationmark.triangle"), imageColor: Color(.systemRed)) {
//                    Text("Error").font(.title2).bold()
//                    Text("Failed to load credentials.")
//                        .font(.subheadline)
//                        .multilineTextAlignment(.center)
//                } buttons: {
//                    SettingsButton("Retry") {
//                        model.loadCredentials()
//                    }
//                }
//            }
        }
        .navigationBarTitle(Text("Manage Passkeys"), displayMode: .inline)
        .alert("Delete Passkey", isPresented: $presentDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let credential = selectedCredentialForDeletion {
                    model.deleteCredential(credential)
                }
                selectedCredentialForDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                selectedCredentialForDeletion = nil
            }
        } message: {
            if let credential = selectedCredentialForDeletion {
                Text("Are you sure you want to delete the passkey for \(credential.rpName ?? credential.rpId)? This action cannot be undone.")
            }
        }
        .alert(error?.localizedDescription ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
            Button(role: .cancel) {
                error = nil
                if model.state.isError() {
                    dismiss()
                }
            } label: {
                Text("OK")
            }
        })
        .onChange(of: model.state) { state in
            if case .error(let error) = state {
                self.error = error
                presentErrorAlert = true
            }
        }
        .onAppear {
            model.loadCredentials()
        }
    }
}

struct CredentialRowView: View {
    let credential: FIDOCredential
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(credential.rpName ?? credential.rpId)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let userDisplayName = credential.userDisplayName {
                        Text(userDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let userName = credential.userName {
                        Text(userName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
//            if let creationDate = credential.creationDate {
//                Text("Created: \(creationDate, style: .date)")
//                    .font(.caption2)
//                    .foregroundColor(.tertiary)
//            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        FIDOCredentialsView()
    }
} 
