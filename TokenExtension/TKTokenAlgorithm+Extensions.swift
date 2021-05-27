//
//  TKTokenAlgorithm+Extensions.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-05-25.
//  Copyright © 2021 Yubico. All rights reserved.
//

import CryptoTokenKit

extension TKTokenKeyAlgorithm {
    var secKeyAlgorithm: SecKeyAlgorithm? {
        
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureRaw) {
            return SecKeyAlgorithm.rsaSignatureRaw
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15Raw) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15Raw
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA1) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA224) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA256) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA384) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA512) {
            return SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA1) {
            return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA224) {
            return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256) {
            return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA384) {
            return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA512) {
            return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPSSSHA1) {
            return SecKeyAlgorithm.rsaSignatureDigestPSSSHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPSSSHA224) {
            return SecKeyAlgorithm.rsaSignatureDigestPSSSHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPSSSHA256) {
            return SecKeyAlgorithm.rsaSignatureDigestPSSSHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPSSSHA384) {
            return SecKeyAlgorithm.rsaSignatureDigestPSSSHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureDigestPSSSHA512) {
            return SecKeyAlgorithm.rsaSignatureDigestPSSSHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePSSSHA1) {
            return SecKeyAlgorithm.rsaSignatureMessagePSSSHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePSSSHA224) {
            return SecKeyAlgorithm.rsaSignatureMessagePSSSHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePSSSHA256) {
            return SecKeyAlgorithm.rsaSignatureMessagePSSSHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePSSSHA384) {
            return SecKeyAlgorithm.rsaSignatureMessagePSSSHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaSignatureMessagePSSSHA512) {
            return SecKeyAlgorithm.rsaSignatureMessagePSSSHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureRFC4754) {
            return SecKeyAlgorithm.ecdsaSignatureRFC4754
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962SHA1) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962SHA224) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962SHA384) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureDigestX962SHA512) {
            return SecKeyAlgorithm.ecdsaSignatureDigestX962SHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureMessageX962SHA1) {
            return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureMessageX962SHA224) {
            return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256) {
            return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureMessageX962SHA384) {
            return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdsaSignatureMessageX962SHA512) {
            return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionRaw) {
            return SecKeyAlgorithm.rsaEncryptionRaw
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionPKCS1) {
            return SecKeyAlgorithm.rsaEncryptionPKCS1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA1) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA224) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA256) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA384) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA512) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA1AESGCM) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA1AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA224AESGCM) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA224AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA256AESGCM) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA256AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA384AESGCM) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA384AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.rsaEncryptionOAEPSHA512AESGCM) {
            return SecKeyAlgorithm.rsaEncryptionOAEPSHA512AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardX963SHA1AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardX963SHA1AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardX963SHA224AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardX963SHA224AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardX963SHA384AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardX963SHA384AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardX963SHA512AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardX963SHA512AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorX963SHA1AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorX963SHA1AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorX963SHA224AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorX963SHA224AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorX963SHA384AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorX963SHA384AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorX963SHA512AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorX963SHA512AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA224AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA224AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA256AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA256AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA384AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA384AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA512AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA512AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA224AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA224AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA384AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA384AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA512AESGCM) {
            return SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA512AESGCM
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandard) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandard
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA1) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA224) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA256) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA384) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA512) {
            return SecKeyAlgorithm.ecdhKeyExchangeStandardX963SHA512
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactor) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactor
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA1) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA1
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA224) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA224
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA256) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA256
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA384) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA384
        }
        if self.isAlgorithm(SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA512) {
            return SecKeyAlgorithm.ecdhKeyExchangeCofactorX963SHA512
        }
        return nil
    }
}
