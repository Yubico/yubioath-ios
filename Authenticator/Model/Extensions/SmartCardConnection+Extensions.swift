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

import Foundation
import YubiKit

// The app has its own OATHSession wrapping YubiKit's.
typealias YubiKitOATHSession = YubiKit.OATHSession
typealias YubiKitOATHSessionError = YubiKit.OATHSessionError

/// Bits of `DeviceInfo.fipsCapabilityFlags`.
enum FIPSCapability {
    static let oath: UInt = 0b00001000
    static let piv: UInt = 0b00010000
}

extension SmartCardConnection {

    /// Returns SCP11b key params if the key requires SCP over NFC for the given FIPS capability.
    /// - Parameter fipsCapability: The bits to check in `fipsCapabilityFlags`, see ``FIPSCapability``.
    private func scp11KeyParamsIfNeeded(fipsCapability: UInt) async throws -> SCP11KeyParams? {
        guard isNFC else { return nil }
        guard let managementSession = try? await Management.Session.makeSession(connection: self) else {
            // CRI-667: the key most likely doesn't support the management application
            return nil
        }
        let deviceInfo = try await managementSession.getDeviceInfo()
        guard deviceInfo.fipsCapabilityFlags & fipsCapability == fipsCapability else { return nil }
        let securityDomainSession = try await SecurityDomainSession.makeSession(connection: self)
        let scpKeyRef = SCPKeyRef(kid: SCPKeyRef.Kid.scp11b, kvn: 0x01)
        guard let certificate = try await securityDomainSession.getCertificateBundle(for: scpKeyRef).last,
              case .ec(let publicKey) = certificate.publicKey else { return nil }
        return try SCP11KeyParams(keyRef: scpKeyRef, pkSdEcka: publicKey)
    }

    /// Creates an OATH session, encrypted with SCP11b if the key requires it.
    /// - Returns: The session and whether it is encrypted.
    func oathSession() async throws -> (session: YubiKitOATHSession, isEncrypted: Bool) {
        let scpKeyParams = try await scp11KeyParamsIfNeeded(fipsCapability: FIPSCapability.oath)
        let session = try await YubiKitOATHSession.makeSession(connection: self, scpKeyParams: scpKeyParams)
        return (session, scpKeyParams != nil)
    }

    /// Creates a PIV session, encrypted with SCP11b if the key requires it.
    func pivSession() async throws -> PIVSession {
        let scpKeyParams = try await scp11KeyParamsIfNeeded(fipsCapability: FIPSCapability.piv)
        return try await PIVSession.makeSession(connection: self, scpKeyParams: scpKeyParams)
    }

    func managementSession() async throws -> Management.Session {
        try await Management.Session.makeSession(connection: self)
    }

    func fido2Session() async throws -> CTAP2.Session {
        try await CTAP2.Session.makeSession(connection: self)
    }
}

nonisolated extension Error {

    private var responseStatus: Response.Status.Code? {
        (self as? any SmartCardSessionError)?.responseStatus?.status
    }

    /// The OATH application is password protected and hasn't been unlocked.
    var isOATHAuthenticationRequired: Bool {
        responseStatus == .securityConditionNotSatisfied
    }

    /// The password used to unlock the OATH application was wrong.
    var isOATHWrongPassword: Bool {
        if case .invalidPassword = self as? YubiKitOATHSessionError { return true }
        return false
    }

    /// The application isn't on the YubiKey or has been disabled.
    var isApplicationNotSupported: Bool {
        switch self {
        case let error as YubiKitOATHSessionError:
            if case .featureNotSupported = error { return true }
        case let error as PIVSessionError:
            if case .featureNotSupported = error { return true }
        case let error as ManagementSessionError:
            if case .featureNotSupported = error { return true }
        case let error as CTAP2.SessionError:
            if case .featureNotSupported = error { return true }
        case let error as SCPError:
            if case .featureNotSupported = error { return true }
        default:
            break
        }
        return false
    }

    /// The status word the YubiKey responded with, if the error is a failed response.
    var statusCode: UInt16? {
        (self as? any SmartCardSessionError)?.responseStatus?.rawStatus
    }

    /// The CTAP error the authenticator responded with.
    var ctapError: CTAP2.Error? {
        if case let .ctapError(error, _) = self as? CTAP2.SessionError { return error }
        return nil
    }

    /// The user cancelled the NFC sheet.
    var isNFCCancelledByUser: Bool {
        switch connectionError {
        case .cancelledByUser, .cancelled: return true
        default: return false
        }
    }

    private var connectionError: SmartCardConnectionError? {
        switch self {
        case let error as SmartCardConnectionError: return error
        case let error as YubiKitOATHSessionError:
            if case let .connectionError(error, _) = error { return error }
        case let error as PIVSessionError:
            if case let .connectionError(error, _) = error { return error }
        case let error as ManagementSessionError:
            if case let .connectionError(error, _) = error { return error }
        case let error as CTAP2.SessionError:
            if case let .connectionError(error, _) = error { return error }
        case let error as SCPError:
            if case let .connectionError(error, _) = error { return error }
        default:
            break
        }
        return nil
    }

    /// A message for errors from YubiKit, or nil if this isn't one.
    var yubiKitErrorDescription: String? {
        if let connectionError {
            switch connectionError {
            case .connectionLost:
                return String(localized: "YubiKey connection lost.")
            case .noDevicesFound:
                return String(localized: "The YubiKey is not connected.")
            case .busy:
                return String(localized: "The key is busy performing another operation.")
            case .cancelled, .cancelledByUser:
                return String(localized: "Connection cancelled by user", comment: "Internal error message not to be displayed to the user.")
            case .unsupported:
                return String(localized: "NFC not supported on this device", comment: "Internal error message not to be displayed to the user.")
            default:
                return String(localized: "YubiKey connection is not found.")
            }
        }
        if isApplicationNotSupported {
            return String(localized: "The requested functionality is missing or disabled in this YubiKey.")
        }
        if responseStatus == .noSpace {
            return String(localized: "The YubiKey has no more storage for OATH accounts.")
        }
        if case .timeout = self as? CTAP2.SessionError {
            return String(localized: "Touch key time out.")
        }
        switch ctapError {
        case .pinInvalid:
            return String(localized: "Wrong PIN.")
        case .pinBlocked:
            return FidoViewModelError.locked.localizedDescription
        case .pinAuthBlocked:
            return String(localized: "Too many wrong PIN attempts. Remove and reinsert the YubiKey to try again.")
        case .pinPolicyViolation:
            return String(localized: "The PIN doesn't meet the requirements of this YubiKey.")
        default:
            break
        }
        switch self {
        case is SmartCardSessionError, is CTAP2.SessionError, is ManagementSessionError:
            return "\(String(localized: "Unknown error.")) (\(self))"
        default:
            return nil
        }
    }
}
