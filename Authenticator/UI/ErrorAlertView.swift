/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import SwiftUI

extension View {
    func errorAlert(error: Binding<Error?>, buttonTitle: String = String(localized: "OK", comment:"OK button in error alert."), handler: (() -> Void)? = nil) -> some View {
        let localizedAlertError = error.wrappedValue.map { LocalizedErrorWrapper(error: $0) }
        
        return alert(isPresented: .constant(localizedAlertError != nil), error: localizedAlertError) { _ in
            Button(buttonTitle) {
                error.wrappedValue = nil
                handler?()
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
    }
}

enum UnknownError: LocalizedError {
    case error
    var errorDescription: String? { String(localized: "Unknown error.") }
}

struct LocalizedErrorWrapper: LocalizedError {
    
    enum ErrorType {
        case nsError(NSError), localizedError(LocalizedError), error(Error)
    }
    
    let underlyingError: ErrorType
    
    var errorDescription: String? {
        switch underlyingError {
        case .nsError(let nsError):
            return nsError.localizedDescription
        case .localizedError(let localizedError):
            return localizedError.errorDescription
        case .error(let error):
            return error.yubiKitErrorDescription ?? "Unknown error: \(error)"
        }
    }
    var recoverySuggestion: String? {
        switch underlyingError {
        case .nsError(let nsError):
            return nsError.localizedRecoverySuggestion
        case .localizedError(let localizedError):
            return localizedError.recoverySuggestion
        case .error(_):
            return nil
        }
    }

    init(error: Error) {
        if type(of: error) is NSError.Type {
            underlyingError = .nsError(error as NSError)
        } else if let localizedError = error as? LocalizedError {
            underlyingError = .localizedError(localizedError)
        } else {
            underlyingError = .error(error)
        }
    }
}
