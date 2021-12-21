//
//  ViewController.swift
//  SSLPinning
//
//  Created by Anuj Rai on 25/01/20.
//  Copyright © 2020 Anuj Rai. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // Actions

    @IBAction func callAPI() {
        guard let url = URL(string: "https://www.google.com") else { return }

        ServiceManager.callAPI(url) { message in
            let alert = UIAlertController(
                title: "SSLPinning",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(
                UIAlertAction(
                    title: "OK",
                    style: .default,
                    handler: nil
                )
            )

            self.present(alert, animated: true, completion: nil)
        }
    }
}

