//
//  SubmittedInfectionViewController.swift
//  TracePrivately
//

import UIKit

class SubmittedInfectionViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = DataManager.shared.persistentContainer.viewContext
        let status = DataManager.shared.diseaseStatus(context: context)

        switch status {
        case .infection:
            self.title = String(format: NSLocalizedString("infection.infected.title", comment: ""), Disease.current.localizedTitle)
        case .infectionPending, .infectionPendingAndExposed:
            self.title = NSLocalizedString("infection.pending.title", comment: "")
        default:
            self.dismiss(animated: false, completion: nil)
            return
        }

        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(Self.doneTapped(_:)))
        self.navigationItem.rightBarButtonItem = button
    }

    @objc func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}
