//
//  MainViewController.swift
//  TracePrivately
//

import UIKit

class MainViewController: UIViewController {

    /// Constants
    
    struct Segue {
        static let viewExposures = "ExposuresSegue"
        static let privacy = "PrivacySegue"
        static let submitInfection = "SubmitInfectionSegue"
        static let viewInfection = "ViewInfectionSegue"
    }

    
    /// Storyboard outlets
    
    @IBOutlet var infectedButton: ActionButton!
    @IBOutlet var pendingButton: ActionButton!
    @IBOutlet var exposedButton: ActionButton!
    
    @IBOutlet var tracingContainer: UIView!
    @IBOutlet var tracingTitleLabel: UILabel!
    @IBOutlet var tracingDescriptionLabel: UILabel!
    @IBOutlet var tracingOnButton: ActionButton!
    @IBOutlet var tracingOffButton: ActionButton!
    @IBOutlet var tracingPrivacyButton: ActionButton!
    @IBOutlet var submitInfectionContainer: UIView!
    @IBOutlet var submitInfectionTitleLabel: UILabel!
    @IBOutlet var submitInfectionDescriptionLabel: UILabel!
    @IBOutlet var submitInfectionButton: ActionButton!
    @IBOutlet var submitInfectionButtonDisabled: ActionButton!

    /// Observers
    
    var statusUpdatingObserver: NSKeyValueObservation?
    var statusObserver: NSKeyValueObservation?

    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("app.title", comment: "")
        
        self.exposedButton.setTitle(NSLocalizedString("exposure.exposed.banner.title", comment: ""), for: .normal)
        self.pendingButton.setTitle(NSLocalizedString("infection.pending.title", comment: ""), for: .normal)
        self.infectedButton.setTitle(NSLocalizedString("infection.infected.title", comment: ""), for: .normal)
        self.tracingOnButton.setTitle(NSLocalizedString("tracing.start.title", comment: ""), for: .normal)
        self.tracingOffButton.setTitle(NSLocalizedString("tracing.stop.title", comment: ""), for: .normal)
        self.tracingPrivacyButton.setTitle(NSLocalizedString("privacy.title", comment: ""), for: .normal)

        self.exposedButton.accessory = .disclosure
        self.infectedButton.accessory = .disclosure
        self.pendingButton.accessory = .disclosure
        
        let submitTitle = String(format: NSLocalizedString("infection.report.title", comment: ""), Disease.current.localizedTitle)
        
        self.submitInfectionButton.setTitle(submitTitle, for: .normal)
        self.submitInfectionButtonDisabled.setTitle(submitTitle, for: .normal)

        self.tracingTitleLabel.text = NSLocalizedString("tracing.title", comment: "")
        self.tracingDescriptionLabel.text = String(format: NSLocalizedString("tracing.message", comment: ""), Disease.current.localizedTitle)
        
        self.submitInfectionTitleLabel.text = NSLocalizedString("infection.title", comment: "")
        self.submitInfectionDescriptionLabel.text = String(format: NSLocalizedString("infection.report.message", comment: ""), Disease.current.localizedTitle)
        
        
        self.infectedButton.isHidden = true
        self.pendingButton.isHidden = true
        self.exposedButton.isHidden = true
        
        let containers: [UIView] = [ self.tracingContainer, self.submitInfectionContainer ]
        
        containers.forEach {
            $0.layer.cornerRadius = 12
            
            if #available(iOS 13, *) {
                $0.layer.cornerCurve = .continuous
            }
        }
        
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: DataManager.exposureContactsUpdatedNotification, object: nil, queue: .main) { _ in
            self.updateViewState(animated: true)
        }
        
        nc.addObserver(forName: DataManager.infectionsUpdatedNotification, object: nil, queue: .main) { _ in
            self.updateViewState(animated: true)
        }
        
        self.statusUpdatingObserver = ContactTraceManager.shared.observe(\.isUpdatingEnabledState, changeHandler: { _, _ in
            DispatchQueue.main.async {
                self.updateViewState(animated: true)
            }
        })
        
        self.statusObserver = ContactTraceManager.shared.observe(\.isContactTracingEnabled, changeHandler: { _, _ in
            DispatchQueue.main.async {
                self.updateViewState(animated: true)
            }
        })

        self.updateViewTheme()
        self.updateViewState(animated: false)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateViewTheme()
    }
    
    func updateViewTheme() {
        let isDarkMode: Bool
        
        if #available(iOS 12, *) {
            isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        }
        else {
            isDarkMode = false
        }
        
        if isDarkMode {
            self.view.backgroundColor = .black
            
            let color = UIColor(white: 0.2, alpha: 1)
            self.tracingContainer.backgroundColor = color
            self.submitInfectionContainer.backgroundColor = color
        }
        else {
            self.view.backgroundColor = .groupTableViewBackground
            self.tracingContainer.backgroundColor = .white
            self.submitInfectionContainer.backgroundColor = .white
        }
    }
    
    func updateViewState(animated: Bool) {
        let status = self.diseaseStatus
        
        switch status {
        case .exposed:
            self.exposedButton.isHidden = false
            self.infectedButton.isHidden = true
            self.pendingButton.isHidden = true
            
        case .infection:
            self.infectedButton.isHidden = false
            self.exposedButton.isHidden = true
            self.pendingButton.isHidden = true
            
        case .infectionPending:
            self.pendingButton.isHidden = false
            self.infectedButton.isHidden = true
            self.exposedButton.isHidden = true
            
        case .infectionPendingAndExposed:
            self.pendingButton.isHidden = false
            self.exposedButton.isHidden = false
            self.infectedButton.isHidden = true
            
        case .nothingDetected:
            self.infectedButton.isHidden = true
            self.exposedButton.isHidden = true
            self.pendingButton.isHidden = true
        }
        
        if status == .infection {
            self.submitInfectionButton.isHidden = true
            self.submitInfectionButtonDisabled.isHidden = false
        }
        else {
            self.submitInfectionButton.isHidden = false
            self.submitInfectionButtonDisabled.isHidden = true
        }
        
        if ContactTraceManager.shared.isUpdatingEnabledState {
            if self.navigationItem.rightBarButtonItem == nil {
                let style: UIActivityIndicatorView.Style
                
                if #available(iOS 13.0, *) {
                    style = .medium
                } else {
                    style = .gray
                }
                
                let indicator = UIActivityIndicatorView(style: style)
                indicator.startAnimating()

                let button = UIBarButtonItem(customView: indicator)

                self.navigationItem.setRightBarButton(button, animated: animated)
            }
        }
        else {
            if self.navigationItem.rightBarButtonItem != nil {
                self.navigationItem.setRightBarButton(nil, animated: animated)
            }
        }
        
        if ContactTraceManager.shared.isContactTracingEnabled {
            self.tracingOnButton.isHidden = true
            self.tracingOffButton.isHidden = false
        }
        else {
            self.tracingOnButton.isHidden = false
            self.tracingOffButton.isHidden = true
        }
    }
}

extension MainViewController {
    var diseaseStatus: DataManager.DiseaseStatus {
        let context = DataManager.shared.persistentContainer.viewContext
        return DataManager.shared.diseaseStatus(context: context)
    }
}

extension MainViewController {
    @IBAction func infectedButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.viewInfection, sender: nil)
    }

    @IBAction func pendingButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.viewInfection, sender: nil)
    }

    @IBAction func exposedButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.viewExposures, sender: nil)
    }
    
    @IBAction func tracingOnButtonTapped(_ sender: ActionButton) {
        guard !ContactTraceManager.shared.isUpdatingEnabledState else {
            return
        }
        
        let haptics = UINotificationFeedbackGenerator()
        haptics.notificationOccurred(.success)

        ContactTraceManager.shared.startTracing { error in
            if let error = error {
                if let error = error as? CTError, error == .permissionDenied {
                    
                }
                else {
                    let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @IBAction func tracingOffButtonTapped(_ sender: ActionButton) {
        let haptics = UINotificationFeedbackGenerator()
        haptics.notificationOccurred(.success)

        ContactTraceManager.shared.stopTracing()
    }

    @IBAction func privacyButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.privacy, sender: nil)
    }

    @IBAction func submitInfectionButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.submitInfection, sender: nil)
    }
}
