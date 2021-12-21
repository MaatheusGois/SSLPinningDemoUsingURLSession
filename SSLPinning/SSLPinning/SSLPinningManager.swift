//
//  SSLPinningManager.swift
//  SSLPinning
//
//  Created by Matheus Gois on 20/12/21.
//  Copyright © 2021 Anuj Rai. All rights reserved.
//

import Foundation

class SSLPinningManager: NSObject, URLSessionDelegate {
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
            validate(for: serverTrust, with: SecPolicyCreateBasicX509()),
            check(for: serverTrust)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

fileprivate extension SSLPinningManager {
    func validate(for trust: SecTrust, with policy: SecPolicy) -> Bool {
        let status = SecTrustSetPolicies(trust, policy)
        guard status == errSecSuccess else { return false }

        return SecTrustEvaluateWithError(trust, nil)
    }

    func check(for serverTrust: SecTrust) -> Bool {
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, .zero) else { return false }
        let serverData = SecCertificateCopyData(serverCertificate) as Data

        return serverData == localCertificate
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
        return certificates.map { SecCertificateCopyData($0) as Data }
    }
}
