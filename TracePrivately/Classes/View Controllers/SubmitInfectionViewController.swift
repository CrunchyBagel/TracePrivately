//
//  SubmitInfectionViewController.swift
//  TracePrivately
//

import UIKit

// TODO: Assuming there will be more fields in future (e.g. pathology lab test ID or photo), prepopulate with any pending submission requests

class SubmitInfectionViewController: UIViewController {

    @IBOutlet var submitButton: ActionButton!
    
    @IBOutlet var infoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = String(format: NSLocalizedString("infection.report.submit.title", comment: ""), Disease.current.localizedTitle)
        
        self.infoLabel.text = String(format: NSLocalizedString("infection.report.message", comment: ""), Disease.current.localizedTitle)
        
        self.submitButton.setTitle(NSLocalizedString("infection.report.submit.title", comment: ""), for: .normal)
        
        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(Self.cancelTapped(_:)))
        self.navigationItem.leftBarButtonItem = button
        
        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }

    }
    
    @objc func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SubmitInfectionViewController {
    @IBAction func submitTapped(_ sender: ActionButton) {
        
        let request = ENSelfExposureInfoRequest()
        
        request.activateWithCompletion { error in
            defer {
                request.invalidate()
            }
             
            guard let exposureInfo = request.selfExposureInfo else {
                var showError = true

                if let error = error as? ENError {
                    switch error.errorCode {
                    case .notAuthorized:
                        showError = false
                    default:
                        break
                    }
                }
                
                if showError {
                    let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error?.localizedDescription ?? NSLocalizedString("infection.report.gathering_data.error", comment: ""), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    
                    self.present(alert, animated: true, completion: nil)
                }
                
                return
            }
            
            // TODO: This isn't a great strategy. We still want the report submitted so the user can continue to submit their daily keys
            
            let keys = exposureInfo.keys

            let alert = UIAlertController(title: NSLocalizedString("infection.report.submit.title", comment: ""), message: NSLocalizedString("infection.report.submit.message", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("submit", comment: ""), style: .destructive, handler: { action in
                
                self.submitReport(keys: keys)
                
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension SubmitInfectionViewController {
    func submitReport(keys: [ENTemporaryExposureKey]) {
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.submitting.title", comment: ""), message: NSLocalizedString("infection.report.submitting.message", comment: ""), preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)

        DataManager.shared.submitReport(keys: keys) { success, error in
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    if success {
                        self.dismiss(animated: true, completion: nil)
                    }
                    else {
                        let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error?.localizedDescription ?? NSLocalizedString("infection.report.submit.error", comment: "" ), preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                }

            }
        }
    }
}
