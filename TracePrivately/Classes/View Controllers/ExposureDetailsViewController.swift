//
//  ExposureDetailsViewController.swift
//  TracePrivately
//

import UIKit

// TODO: Treat an exposure as unread until user visits this screen, then mark it as viewed and update the app badge accordingly.

class ExposureDetailsViewController: UIViewController {

    var contact: ExposureContactInfoEntity!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("exposure.exposed.details.title", comment: "")
    }
}
