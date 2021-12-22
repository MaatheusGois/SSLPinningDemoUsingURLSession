//
//  ServiceManager.swift
//  SSLPinning
//
//  Created by Anuj Rai on 26/01/20.
//  Copyright © 2020 Anuj Rai. All rights reserved.
//

import Foundation
import Security
import CommonCrypto

class ServiceManager: NSObject {
    static func callAPI(_ url: URL, completion: @escaping (String) -> Void) {
        let session = URLSession(
            configuration: .ephemeral,
            delegate: SSLPinningManager(),
            delegateQueue: nil
        )

        

        var responseMessage = ""
        let task = session.dataTask(with: url) { data, _, error in
            if let error = error {
                responseMessage = error.localizedDescription
            } else if data != nil {
                responseMessage = "Certificate pinning is successfully completed"
            }
            
            DispatchQueue.main.async { completion(responseMessage) }
        }
        task.resume()
    }
}
