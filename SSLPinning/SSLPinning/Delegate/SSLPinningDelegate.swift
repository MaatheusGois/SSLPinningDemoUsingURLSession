//
//  SSLPinningManager.swift
//  SSLPinning
//
//  Created by Matheus Gois on 20/12/21.
//  Copyright © 2021 Anuj Rai. All rights reserved.
//

import Foundation
import CommonCrypto
import CryptoKit

class SSLPinningDelegate: NSObject, URLSessionDelegate {
    var localCertificate: Data? {
        guard let localCertificateUrl = Bundle.main.url(forResource: "google", withExtension: ".cer")  else { return nil }
        return try? Data(contentsOf: localCertificateUrl)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard
            validate(for: serverTrust),
            checkCertificate(for: serverTrust),
            checkPublicKey(for: serverTrust)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

fileprivate extension SSLPinningDelegate {
    func validate(for trust: SecTrust, with policy: SecPolicy = SecPolicyCreateBasicX509()) -> Bool {
        let status = SecTrustSetPolicies(trust, policy)
        guard status == errSecSuccess else { return false }

        return SecTrustEvaluateWithError(trust, nil)
    }

    func checkCertificate(for serverTrust: SecTrust) -> Bool {
        guard let serverData = SecTrustGetCertificateAtIndex(serverTrust, .zero)?.data else { return false }

        return serverData == localCertificate
    }

    func checkPublicKey(for serverTrust: SecTrust) -> Bool {
        guard let serverData = SecTrustGetCertificateAtIndex(serverTrust, .zero)?.data else { return false }

        return serverData.hash() == localCertificate?.hash()
    }

    func publicKey(for certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?

        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)

        if let trust = trust, trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }

        return publicKey
    }

    func certificateData(for certificates: [SecCertificate]) -> [Data] {
        return certificates.map { $0.data }
    }
}

fileprivate extension SecCertificate {
    var data: Data { SecCertificateCopyData(self) as Data }
}

fileprivate extension Data {
    /// ASN1 header for our public key to re-create the subject public key info
    private static let rsa2048Asn1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    /// Creates a hash from the received data using the `sha256` algorithm.
    /// `Returns` the `base64` encoded representation of the hash.
    ///
    /// To replicate the output of the `openssl dgst -sha256` command, an array of specific bytes need to be appended to
    /// the beginning of the data to be hashed.
    /// - Parameter data: The data to be hashed.
    func hash() -> String {

        // Add the missing ASN1 header for public keys to re-create the subject public key info
        var keyWithHeader = Data(Data.rsa2048Asn1Header)
        keyWithHeader.append(self)

        // Check if iOS 13 is available, and use CryptoKit's hasher
        if #available(iOS 13, *) {
            return Data(SHA256.hash(data: keyWithHeader)).base64EncodedString()
        } else {
            var hash = [UInt8](repeating: .zero, count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = keyWithHeader.withUnsafeBytes {
                CC_SHA256($0.baseAddress, CC_LONG(keyWithHeader.count), &hash)
            }
            return Data(hash).base64EncodedString()
        }
    }
}
