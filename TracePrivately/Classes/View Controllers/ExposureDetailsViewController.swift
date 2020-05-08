//
//  ExposureDetailsViewController.swift
//  TracePrivately
//

import UIKit

class ExposureDetailsViewController: UIViewController {

    var contact: ExposureContactInfoEntity!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("exposure.exposed.details.title", comment: "")
        
        DataManager.shared.updateStatus(exposure: self.contact, status: .read) { _ in
            
        }
    }
}
