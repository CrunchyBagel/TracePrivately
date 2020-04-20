//
//  SubmittedInfectionViewController.swift
//  TracePrivately
//
//  Created by Quentin Zervaas on 20/4/20.
//  Copyright © 2020 Quentin Zervaas. All rights reserved.
//

import UIKit

class SubmittedInfectionViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("infection.infected.title", comment: "")

        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(Self.doneTapped(_:)))
        self.navigationItem.leftBarButtonItem = button
    }

    
    @objc func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}
