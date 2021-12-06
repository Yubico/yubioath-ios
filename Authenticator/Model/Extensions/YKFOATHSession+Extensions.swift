//
//  YKFOATHSession+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-11-08.
//  Copyright © 2021 Yubico. All rights reserved.
//

extension YKFOATHSession {
    func calculateSteamTOTP(credential: Credential, completion: @escaping ((String?, DateInterval?, Error?) -> Void)) {
        var challenge = Data()
        let timestamp = Date().addingTimeInterval(10)
        let value: UInt64 = UInt64(timestamp.timeIntervalSince1970 / TimeInterval(credential.period))
        var bigEndianVal = value.bigEndian
        withUnsafePointer(to: &bigEndianVal) {
            challenge.append(UnsafeBufferPointer(start: $0, count: 1))
        }
        self.calculateResponse(forCredentialID: Data(credential.uniqueId.utf8), challenge: challenge) { response, error in
            guard let response = response else {
                completion(nil, nil, error!)
                return
            }

            let offset = Int(response.last! & 0x0F)
            let subdata = response.subdata(in: offset..<Int(offset + 4))
            let steamChars = Array("23456789BCDFGHJKMNPQRTVWXY")
            var number = UInt32(bigEndian: subdata.uint32 ?? 0) & 0x7fffffff
            var steamCode = ""
            for _ in 0...4 {
                steamCode.append(steamChars[Int(number) % steamChars.count])
                number /= UInt32(steamChars.count)
            }
            let startDate = Date(timeIntervalSince1970: TimeInterval(Int(timestamp.timeIntervalSince1970) - Int(timestamp.timeIntervalSince1970) % 30))
            let validity = DateInterval(start: startDate, duration: 30)
            completion(steamCode, validity, nil)
        }
    }
}
