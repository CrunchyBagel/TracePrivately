//
//  SubmitInfectionViewController.swift
//  TracePrivately
//

import UIKit

// TODO: Assuming there will be more fields in future (e.g. pathology lab test ID or photo), prepopulate with any pending submission requests

class SubmitInfectionViewController: UIViewController {

    @IBOutlet var submitButton: ActionButton!
    
    @IBOutlet var infoLabel: UILabel!
    
    var config: SubmitInfectionConfig = .empty
    
    // Holds the form elements
    @IBOutlet var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = Bundle.main.url(forResource: "SubmitConfig", withExtension: "plist") {
            if let config = SubmitInfectionConfig(plistUrl: url) {
                self.config = config
            }
        }
        
        // TODO: Make use of config in this form
        
        self.title = String(format: NSLocalizedString("infection.report.submit.title", comment: ""), Disease.current.localizedTitle)
        
        self.infoLabel.text = String(format: NSLocalizedString("infection.report.message", comment: ""), Disease.current.localizedTitle)
        
        self.submitButton.setTitle(NSLocalizedString("infection.report.submit.title", comment: ""), for: .normal)
        
        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(Self.cancelTapped(_:)))
        self.navigationItem.leftBarButtonItem = button
        
        let elements = self.config.sortedFields.compactMap { self.createFormElement(field: $0) }
        
        elements.forEach { self.stackView.insertArrangedSubview($0, at: elements.count - 1) }

      if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
    }
    
    @objc func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SubmitInfectionViewController {
    func createFormElement(field: SubmitInfectionConfig.Field) -> UIView? {
        let isDarkMode: Bool
        
        if #available(iOS 12, *) {
            isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        }
        else {
            isDarkMode = false
        }

        var subViews: [UIView] = []
        
        if let str = field.localizedTitle {
            let label = UILabel()
            label.text = str
            label.font = UIFont.preferredFont(forTextStyle: .headline)
            label.numberOfLines = 0
            
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = isDarkMode ? .white : .black
            }
            
            subViews.append(label)
        }
        
        if let str = field.localizedDescription {
            let label = UILabel()
            label.text = str
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.numberOfLines = 0
            
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = isDarkMode ? .white : .black
            }

            subViews.append(label)
        }

        switch field.type {
        case .shortText:
            
            let textField = UITextField()
            textField.placeholder = field.placeholder
            
            subViews.append(textField)

        case .photo:
            // A container with a button to open the photo picker and an image view for preview
            
            let button = UIButton(type: .custom)
            
            let previewImageView = UIImageView()
            
            
            let stackView = UIStackView(arrangedSubviews: [ button, previewImageView ])
            stackView.axis = .horizontal
            
            subViews.append(stackView)

        case .longText:
            let textView = UITextView()
            subViews.append(textView)
        }
        
        
        let stackView = UIStackView(arrangedSubviews: subViews)
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.addSubview(stackView)
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        
        return container
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
    private func formDataForField(field: SubmitInfectionConfig.Field) -> InfectedKeysFormDataField? {
        
        // TODO: Complete this
        return nil
    }
    
    var gatherFormData: InfectedKeysFormData {
        let fields: [InfectedKeysFormDataField] = self.config.sortedFields.compactMap { self.formDataForField(field: $0) }
        
        return InfectedKeysFormData(fields: fields)
    }
}

extension SubmitInfectionViewController {
    // TODO: Make it super clear to the user if an error occurred, so they have an opportunity to submit again
    
    func submitReport(keys: [ENTemporaryExposureKey]) {
        
        let formData = self.gatherFormData
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.submitting.title", comment: ""), message: NSLocalizedString("infection.report.submitting.message", comment: ""), preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)

        DataManager.shared.submitReport(formData: formData, keys: keys) { success, error in
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
