//
//  SettingsViewController.swift
//  TracePrivately
//
//  Created by Quentin Zervaas on 28/4/20.
//  Copyright © 2020 Quentin Zervaas. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet var resetKeysButton: ActionButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("settings.title", comment: "")

        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(Self.doneTapped(_:)))
        self.navigationItem.rightBarButtonItem = button
        
        self.resetKeysButton.setTitle(NSLocalizedString("reset_keys.title", comment: ""), for: .normal)
    }

    @objc func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController {
    @IBAction func resetKeysTapped(_ sender: ActionButton) {
        let alert = UIAlertController(title: NSLocalizedString("reset_keys.title", comment: ""), message: NSLocalizedString("reset_keys.message", comment: ""), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("reset_keys.button.title", comment: ""), style: .destructive, handler: { _ in
            
            let haptics = UINotificationFeedbackGenerator()
            haptics.notificationOccurred(.success)

            let request = ENSelfExposureResetRequest()
            
            request.activateWithCompletion { _ in
                defer {
                    request.invalidate()
                }

                DataManager.shared.deleteLocalInfections { _ in

                }
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}
