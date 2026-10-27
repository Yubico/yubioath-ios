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

import Foundation
import OSLog
import YubiKit

/// Owns the app's YubiKey connections.
///
/// YubiKit allows one wired connection at a time and a pending wired connection can't be cancelled, so a
/// single loop waits for wired YubiKeys for the lifetime of the app. Like the YubiKitManager delegate it
/// replaces, only the most recent subscriber is handed wired connections. When that subscriber goes away
/// the previous one is told about any change it missed.
///
/// NFC connections are opened on demand. YubiKit only reports the closing of an NFC connection to a single
/// waiter, so use ``waitUntilClosed(_:)`` here instead of calling `waitUntilClosed()` on an NFC connection.
final class ConnectionManager {

    nonisolated static let shared = ConnectionManager()

    private(set) var wiredConnection: SmartCardConnection?
    private(set) var nfcConnection: NFCSmartCardConnection?

    private struct Subscriber {
        let id: UUID
        let continuation: AsyncStream<SmartCardConnection?>.Continuation
        // The wired connection generation last yielded, nil if none or if it was removed.
        var delivered: Int?
    }

    private var subscribers: [Subscriber] = []
    private var wiredGeneration: Int?
    private var wiredWaiters: [UUID: CheckedContinuation<SmartCardConnection, Error>] = [:]
    private var isWiredSuspended = false
    private var resumeWiredLoop: CheckedContinuation<Void, Never>?
    private var nfcCloseWaiters: [CheckedContinuation<Error?, Never>] = []

    nonisolated private init() {
        Logger.allocation.debug("ConnectionManager: init")
        #if !targetEnvironment(simulator)
        // There are no USB smart card slots in the simulator and YubiKit asserts when it can't find any.
        Task { await runWiredLoop() }
        #endif
    }

    // MARK: - Wired connections

    /// Yields the wired connection whenever a YubiKey is inserted and nil when it's removed.
    ///
    /// Only the most recent subscriber receives updates. Stop iterating to unsubscribe.
    func wiredConnections() -> AsyncStream<SmartCardConnection?> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: SmartCardConnection?.self, bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { _ in
            Task { @MainActor in ConnectionManager.shared.unsubscribe(id) }
        }
        subscribers.append(Subscriber(id: id, continuation: continuation))
        deliverToCurrentSubscriber()
        return stream
    }

    /// Returns the wired connection, waiting for a YubiKey to be inserted if needed.
    func nextWiredConnection() async throws -> SmartCardConnection {
        if let wiredConnection { return wiredConnection }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                wiredWaiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                ConnectionManager.shared.wiredWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
            }
        }
    }

    /// Closes the wired connection and stops connecting to wired YubiKeys until ``resumeWiredConnections()``.
    func suspendWiredConnections() {
        Logger.connection.debug("ConnectionManager: suspend wired connections")
        isWiredSuspended = true
        if let wiredConnection {
            Task { await wiredConnection.close(error: nil) }
        }
    }

    func resumeWiredConnections() {
        guard isWiredSuspended else { return }
        Logger.connection.debug("ConnectionManager: resume wired connections")
        isWiredSuspended = false
        resumeWiredLoop?.resume()
        resumeWiredLoop = nil
    }

    /// Closes the wired connection. The YubiKey is connected to again if it's still inserted.
    func restartWiredConnection() {
        if let wiredConnection {
            Task { await wiredConnection.close(error: nil) }
        }
    }

    private func runWiredLoop() async {
        var generation = 0
        while true {
            if isWiredSuspended {
                await withCheckedContinuation { resumeWiredLoop = $0 }
            }
            do {
                let connection = try await WiredSmartCardConnection.makeConnection()
                guard !isWiredSuspended else {
                    await connection.close(error: nil)
                    continue
                }
                generation += 1
                Logger.connection.debug("ConnectionManager: wired connection \(generation)")
                wiredConnection = connection
                wiredGeneration = generation
                wiredWaiters.values.forEach { $0.resume(returning: connection) }
                wiredWaiters.removeAll()
                deliverToCurrentSubscriber()

                let error = await connection.waitUntilClosed()
                Logger.connection.debug("ConnectionManager: wired connection \(generation) closed, error: \(String(describing: error))")
                wiredConnection = nil
                wiredGeneration = nil
                deliverToCurrentSubscriber()
            } catch {
                Logger.connection.debug("ConnectionManager: failed to connect to wired YubiKey: \(String(describing: error))")
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func unsubscribe(_ id: UUID) {
        subscribers.removeAll { $0.id == id }
        deliverToCurrentSubscriber()
    }

    private func deliverToCurrentSubscriber() {
        guard var subscriber = subscribers.last, subscriber.delivered != wiredGeneration else { return }
        subscriber.continuation.yield(wiredConnection)
        subscriber.delivered = wiredGeneration
        subscribers[subscribers.count - 1] = subscriber
    }

    // MARK: - NFC connections

    /// Returns the open NFC connection, or presents the NFC sheet and waits for a YubiKey.
    func nfcConnection(alertMessage: String? = nil) async throws -> NFCSmartCardConnection {
        if let nfcConnection { return nfcConnection }
        guard DeviceCapabilities.supportsNFC else { throw SmartCardConnectionError.unsupported }
        let message = alertMessage ?? String(localized: "Scan your YubiKey", comment: "iOS NFC alert scan")
        let connection = try await NFCSmartCardConnection(alertMessage: message)
        Logger.connection.debug("ConnectionManager: NFC connection")
        nfcConnection = connection
        Task {
            let error = await connection.waitUntilClosed()
            Logger.connection.debug("ConnectionManager: NFC connection closed, error: \(String(describing: error))")
            nfcConnection = nil
            nfcCloseWaiters.forEach { $0.resume(returning: error) }
            nfcCloseWaiters.removeAll()
        }
        return connection
    }

    /// Returns the wired connection if there is one, otherwise an NFC connection. Without NFC it waits for
    /// a YubiKey to be inserted.
    func anyConnection(alertMessage: String? = nil) async throws -> SmartCardConnection {
        if let wiredConnection { return wiredConnection }
        if DeviceCapabilities.supportsNFC {
            return try await nfcConnection(alertMessage: alertMessage)
        }
        return try await nextWiredConnection()
    }

    /// Waits until the connection closes and returns the error it was closed with, if any.
    func waitUntilClosed(_ connection: SmartCardConnection) async -> Error? {
        guard connection is NFCSmartCardConnection else {
            return await connection.waitUntilClosed()
        }
        guard nfcConnection != nil else { return nil }
        return await withCheckedContinuation { nfcCloseWaiters.append($0) }
    }

    /// Closes the NFC connection showing a success message in the NFC sheet.
    nonisolated func closeNFC(message: String? = nil) {
        Task { @MainActor in
            await ConnectionManager.shared.nfcConnection?.close(message: message ?? String(localized: "Success", comment: "iOS NFC alert default success message"))
        }
    }

    /// Closes the NFC connection showing an error message in the NFC sheet.
    nonisolated func closeNFC(errorMessage: String) {
        Task { @MainActor in
            await ConnectionManager.shared.nfcConnection?.close(error: NFCErrorMessage(errorDescription: errorMessage))
        }
    }
}

/// An error whose description is shown in the NFC sheet when it's closed.
private struct NFCErrorMessage: LocalizedError {
    let errorDescription: String?
}

extension SmartCardConnection {
    var isNFC: Bool { self is NFCSmartCardConnection }
}
