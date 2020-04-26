//
//  PrivacyViewController.swift
//  TracePrivately
//

import UIKit

class PrivacyViewController: UIViewController {

    @IBOutlet var okButton: ActionButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("privacy.title", comment: "")
        
        self.okButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
    }
    
    @IBAction func doneTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
