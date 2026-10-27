/*
 * Copyright (C) 2022 Yubico.
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

import OSLog
import YubiKit

final class SmartCardViewModel {

    struct Certificate {
        let certificate: SecCertificate
        let slot: PIV.Slot
    }

    private let tokenStorage = TokenCertificateStorage()
    private var wiredConnectionsTask: Task<Void, Never>?

    var certificatesCallback: ((_ result: Result<[Certificate]?, Error>) -> Void)?
    var tokensCallback: ((_ result: Result<[SecCertificate], Error>) -> Void)?

    init() {
        Logger.allocation.debug("SmartCardViewModel: init")
    }

    deinit {
        wiredConnectionsTask?.cancel()
        Logger.allocation.debug("SmartCardViewModel: deinit")
    }

    /// Lists the stored tokens and reads the certificates of wired YubiKeys until ``stop()``.
    func start() {
        tokensCallback?(.success(tokenStorage.listTokenCertificates()))
        wiredConnectionsTask?.cancel()
        wiredConnectionsTask = Task { [weak self] in
            for await connection in ConnectionManager.shared.wiredConnections() {
                if let connection {
                    await self?.readCertificates(connection: connection)
                } else {
                    self?.certificatesCallback?(.success(nil))
                }
            }
        }
    }

    func stop() {
        wiredConnectionsTask?.cancel()
        wiredConnectionsTask = nil
    }

    func startNFC() {
        guard DeviceCapabilities.supportsNFC else { return }
        Task {
            do {
                let connection = try await ConnectionManager.shared.nfcConnection()
                await readCertificates(connection: connection)
            } catch where error.isNFCCancelledByUser {
                // The user dismissed the NFC sheet.
            } catch {
                certificatesCallback?(.failure(error))
            }
        }
    }

    func storeTokenCertificate(certificate: SecCertificate) -> Error? {
        return tokenStorage.storeTokenCertificate(certificate: certificate)
    }

    func removeTokenCertificate(certificate: SecCertificate) {
        let result = tokenStorage.removeTokenCertificate(certificate: certificate)
        result ? Logger.ctk.debug("Sucessfully removed certificate from keychain") : Logger.ctk.debug("Failed removing certificate from keychain!")
    }

    func update() {
        tokensCallback?(.success(tokenStorage.listTokenCertificates()))
        guard let connection = ConnectionManager.shared.wiredConnection else { return }
        Task {
            await readCertificates(connection: connection)
        }
    }

    private func readCertificates(connection: SmartCardConnection) async {
        do {
            let session = try await connection.pivSession()
            var certificates = [Certificate]()
            for slot in PIV.Slot.allSlots {
                if let certificate = try await session.certificate(in: slot) {
                    certificates.append(Certificate(certificate: certificate, slot: slot))
                }
            }
            certificatesCallback?(.success(certificates))
            ConnectionManager.shared.closeNFC(message: String(localized: "Finished reading certificates", comment: "PIV extension NFC finished reading certs"))
        } catch {
            certificatesCallback?(.failure(error))
            ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
        }
    }
}

nonisolated extension PIV.Slot {
    static let allSlots: [PIV.Slot] = [
        .authentication, .signature, .keyManagement, .cardAuth,
        .retired1, .retired2, .retired3, .retired4, .retired5,
        .retired6, .retired7, .retired8, .retired9, .retired10,
        .retired11, .retired12, .retired13, .retired14, .retired15,
        .retired16, .retired17, .retired18, .retired19, .retired20
    ]
}

extension PIVSession {
    /// The certificate in the slot, or nil if the slot is empty.
    func certificate(in slot: PIV.Slot) async throws -> SecCertificate? {
        do {
            let certificate = try await getCertificate(in: slot)
            return SecCertificateCreateWithData(nil, certificate.der as CFData)
        } catch {
            switch error {
            case .failedResponse(let response, _) where response.responseStatus.status == .fileNotFound:
                // No certificate in slot - not an error
                return nil
            case .responseParseError:
                return nil
            default:
                throw error
            }
        }
    }
}
