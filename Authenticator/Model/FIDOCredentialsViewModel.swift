import Foundation
import SwiftUI
import OSLog

enum FIDOCredentialsViewModelError: Error, LocalizedError {
    
    case usbNotSupported, timeout, locked, notSupportedOverLightning
    
    public var errorDescription: String? {
        switch self {
        case .usbNotSupported:
            return String(localized: "FIDO management over USB-C is not supported by iOS. Use NFC or the desktop Yubico Authenticator instead.")
        case .timeout:
            return String(localized: "Operation timed out.")
        case .locked:
            return String(localized: "PIN is permanently blocked. Factory reset FIDO application to continue.")
        case .notSupportedOverLightning:
            return String(localized: "This operation is not supported over Lightning on this YubiKey. Please use Yubico Authenticator for desktop to reset the FIDO application.")
        }
    }
}

struct FIDOCredential: Identifiable, Equatable {
    let id: String
    let rpId: String
    let rpName: String?
    let userDisplayName: String?
    let userName: String?
    let creationDate: Date?
    
    static func == (lhs: FIDOCredential, rhs: FIDOCredential) -> Bool {
        return lhs.id == rhs.id
    }
}

class FIDOCredentialsViewModel: ObservableObject {
    
    @Published var state: CredentialsState = .unknown
    @Published var isProcessing: Bool = false
    @Published var credentials: [FIDOCredential] = []
    
    enum CredentialsState: Equatable {
        
        case unknown, loaded, error(Error), keyRemoved
        
        static func == (lhs: FIDOCredentialsViewModel.CredentialsState, rhs: FIDOCredentialsViewModel.CredentialsState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.loaded, .loaded):
                return true
            case (.error(_), .error(_)):
                return true
            case (.keyRemoved, .keyRemoved):
                return true
            default:
                return false
            }
        }
        
        func isError() -> Bool {
            switch self {
            case .error(_):
                return true
            default:
                return false
            }
        }
    }
    
    init() {
        loadCredentials()
    }
    
    func loadCredentials() {
        self.isProcessing = true
        self.state = .unknown
        
        // Mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.credentials = [
                FIDOCredential(
                    id: "sample1",
                    rpId: "example.com",
                    rpName: "Example Site",
                    userDisplayName: "John Doe",
                    userName: "john@example.com",
                    creationDate: Date()
                ),
                FIDOCredential(
                    id: "sample2",
                    rpId: "github.com",
                    rpName: "GitHub",
                    userDisplayName: "Jane Smith",
                    userName: "jane@github.com",
                    creationDate: Date().addingTimeInterval(-86400)
                )
            ]
            self.state = .loaded
            self.isProcessing = false
        }
    }
    
    func deleteCredential(_ credential: FIDOCredential) {
        self.isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.credentials.removeAll { $0.id == credential.id }
            self.isProcessing = false
        }
    }
} 