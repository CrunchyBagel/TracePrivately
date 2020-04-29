//
//  MainViewController.swift
//  TracePrivately
//

import UIKit
import ExposureNotification

class MainViewController: UIViewController {

    /// Constants
    
    struct Segue {
        static let viewExposures = "ExposuresSegue"
        static let privacy = "PrivacySegue"
        static let submitInfection = "SubmitInfectionSegue"
        static let viewInfection = "ViewInfectionSegue"
        static let settings = "SettingsSegue"
    }

    
    /// Storyboard outlets
    
    @IBOutlet var noIssuesButton: ActionButton!
    @IBOutlet var infectedButton: ActionButton!
    @IBOutlet var pendingButton: ActionButton!
    @IBOutlet var exposedButton: ActionButton!
    
    @IBOutlet var tracingContainer: UIView!
    @IBOutlet var tracingTitleLabel: UILabel!
    @IBOutlet var tracingDescriptionLabel: UILabel!
    @IBOutlet var tracingOnButton: ActionButton!
    @IBOutlet var tracingOffButton: ActionButton!
    @IBOutlet var tracingLoadingButton: ActionButton!
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

        self.title = String(format: NSLocalizedString("app.title", comment: ""), Disease.current.localizedTitle)
        
        self.noIssuesButton.setTitle(String(format: NSLocalizedString("exposure.none.banner.title", comment: ""), Disease.current.localizedTitle), for: .normal)
        self.exposedButton.setTitle(String(format: NSLocalizedString("exposure.exposed.banner.title", comment: ""), Disease.current.localizedTitle), for: .normal)
        self.pendingButton.setTitle(NSLocalizedString("infection.pending.title", comment: ""), for: .normal)
        self.infectedButton.setTitle(String(format: NSLocalizedString("infection.infected.title", comment: ""), Disease.current.localizedTitle), for: .normal)
        self.tracingOnButton.setTitle(NSLocalizedString("tracing.start.title", comment: ""), for: .normal)
        self.tracingOffButton.setTitle(NSLocalizedString("tracing.stop.title", comment: ""), for: .normal)
        self.tracingPrivacyButton.setTitle(NSLocalizedString("privacy.title", comment: ""), for: .normal)
        
        self.tracingLoadingButton.setTitle(nil, for: .normal)
        self.tracingLoadingButton.isEnabled = false
        
        let style: UIActivityIndicatorView.Style
        
        if #available(iOS 13.0, *) {
            style = .medium
        } else {
            style = .gray
        }
        
        let indicator = UIActivityIndicatorView(style: style)
        indicator.startAnimating()
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        self.tracingLoadingButton.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: self.tracingLoadingButton.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: self.tracingLoadingButton.centerYAnchor)
        ])

        self.noIssuesButton.accessory = .disclosure
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
        
        self.noIssuesButton.isHidden = false
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
        
        var settingsButton: UIBarButtonItem?
        
        if #available(iOS 13.0, *) {
            if let image = UIImage(systemName: "ellipsis.circle.fill") {
                settingsButton = UIBarButtonItem(image: image, style: .done, target: self, action: #selector(Self.settingsTapped(_:)))
            }
        }
            
        if settingsButton == nil {
            settingsButton = UIBarButtonItem(title: NSLocalizedString("settings.title", comment: ""), style: .done, target: self, action: #selector(Self.settingsTapped(_:)))
        }
        
        self.navigationItem.rightBarButtonItem = settingsButton
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
            self.noIssuesButton.isHidden = true

        case .infection:
            self.infectedButton.isHidden = false
            self.exposedButton.isHidden = true
            self.pendingButton.isHidden = true
            self.noIssuesButton.isHidden = true

        case .infectionPending:
            self.pendingButton.isHidden = false
            self.infectedButton.isHidden = true
            self.exposedButton.isHidden = true
            self.noIssuesButton.isHidden = true

        case .infectionPendingAndExposed:
            self.pendingButton.isHidden = false
            self.exposedButton.isHidden = false
            self.infectedButton.isHidden = true
            self.noIssuesButton.isHidden = true

        case .nothingDetected:
            self.infectedButton.isHidden = true
            self.exposedButton.isHidden = true
            self.pendingButton.isHidden = true
            self.noIssuesButton.isHidden = false
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
            self.tracingLoadingButton.isHidden = false
            self.tracingOnButton.isHidden = true
            self.tracingOffButton.isHidden = true
        }
        else if ContactTraceManager.shared.isContactTracingEnabled {
            self.tracingOnButton.isHidden = true
            self.tracingOffButton.isHidden = false
            self.tracingLoadingButton.isHidden = true
        }
        else {
            self.tracingOnButton.isHidden = false
            self.tracingOffButton.isHidden = true
            self.tracingLoadingButton.isHidden = true
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
    @objc func settingsTapped(_ sender: Any) {
        self.performSegue(withIdentifier: Segue.settings, sender: nil)
    }

    @IBAction func noIssuesButtonTapped(_ sender: ActionButton) {
        self.performSegue(withIdentifier: Segue.viewExposures, sender: nil)
    }

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
            print("Already updating state, ignoring this tap")
            return
        }
        
        let haptics = UINotificationFeedbackGenerator()
        haptics.notificationOccurred(.success)

        ContactTraceManager.shared.startTracing { error in
            if let error = error {
                if let error = error as? ENError, error.code == .notAuthorized {
                    
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
