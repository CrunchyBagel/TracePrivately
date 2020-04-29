//
//  SubmitInfectionViewController.swift
//  TracePrivately
//

import UIKit

class SubmitInfectionViewController: UIViewController {

    struct FormValidationError: LocalizedError {
        enum ErrorType {
            case valueMissing
            case valueInvalid
            
        }
        let field: SubmitInfectionConfig.Field
        let errorType: ErrorType
        
        var errorDescription: String? {
            switch errorType {
            case .valueInvalid:
                return NSLocalizedString("infection.report.form.error.value_invalid", comment: "")
            case .valueMissing:
                return NSLocalizedString("infection.report.form.error.value_missing", comment: "")
            }
        }
    }
    
    @IBOutlet var submitButton: ActionButton!
    @IBOutlet var submitLoadingButton: ActionButton!

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
        
        self.title = String(format: NSLocalizedString("infection.report.submit.title", comment: ""), Disease.current.localizedTitle)
        
        self.infoLabel.text = String(format: NSLocalizedString("infection.report.message", comment: ""), Disease.current.localizedTitle)
        
        self.submitButton.setTitle(NSLocalizedString("infection.report.submit.title", comment: ""), for: .normal)
        
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
        
        self.submitLoadingButton.addSubview(indicator)
        self.submitLoadingButton.isHidden = true
        self.submitLoadingButton.setTitle(nil, for: .normal)
        self.submitLoadingButton.isEnabled = false
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: self.submitLoadingButton.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: self.submitLoadingButton.centerYAnchor)
        ])

        
        
        
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

class SubmitInfectionFormContainerView: UIView {
    let formName: String
    
    init(formName: String) {
        self.formName = formName
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
    
    var formField: InfectedKeysFormDataField? {
        print("Not implemented for \(formName)")
        return nil
    }
}

class SubmitInfectionFormShortTextContainerView: SubmitInfectionFormContainerView {
    var textField: UITextField?
    
    override var formField: InfectedKeysFormDataField? {
        guard let text = self.textField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        
        guard text.count > 0 else {
            return nil
        }
        
        return InfectedKeysFormDataStringField(name: self.formName, value: text)
    }
}

class SubmitInfectionFormLongTextContainerView: SubmitInfectionFormContainerView {
    var textView: UITextView?

    override var formField: InfectedKeysFormDataField? {
        guard let text = self.textView?.text.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        guard text.count > 0 else {
            return nil
        }

        return InfectedKeysFormDataStringField(name: self.formName, value: text)
    }
}

class SubmitInfectionFormPhotoContainerView: SubmitInfectionFormContainerView {
    
}

extension SubmitInfectionViewController {
    func createFormElement(field: SubmitInfectionConfig.Field) -> SubmitInfectionFormContainerView? {
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

        let container: SubmitInfectionFormContainerView

        switch field.type {
        case .shortText:
            
            let textField = UITextField()
            textField.placeholder = field.placeholder
            
            subViews.append(textField)

            let c = SubmitInfectionFormShortTextContainerView(formName: field.formName)
            c.textField = textField
            
            container = c

        case .longText:
            let textView = UITextView()
            subViews.append(textView)
            
            let c = SubmitInfectionFormLongTextContainerView(formName: field.formName)
            
            container = c

        case .photo:
            // A container with a button to open the photo picker and an image view for preview
            
            let button = UIButton(type: .custom)
            
            let previewImageView = UIImageView()
            
            
            let stackView = UIStackView(arrangedSubviews: [ button, previewImageView ])
            stackView.axis = .horizontal
            
            subViews.append(stackView)

            let c = SubmitInfectionFormPhotoContainerView(formName: field.formName)
            
            
            container = c
        }
        
        
        let stackView = UIStackView(arrangedSubviews: subViews)
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
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
    func presentErrorAlert(title: String?, message: String?) {
        
        let title = title ?? NSLocalizedString("error", comment: "")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func submitTapped(_ sender: ActionButton) {
        
        self.submitButton.isHidden = true
        self.submitLoadingButton.isHidden = false
        
        self.runSubmitWorkflow { didSubmit, error in
            DispatchQueue.main.async {
                if didSubmit {
                    self.dismiss(animated: true, completion: nil)
                }
                else {
                    self.submitButton.isHidden = false
                    self.submitLoadingButton.isHidden = true
                }
            }
        }
    }
    
    func runSubmitWorkflow(completion: @escaping (Bool, Swift.Error?) -> Void) {
        do {
            try self.assertFormIsValid()
        }
        catch let e as FormValidationError {
            self.presentErrorAlert(title: e.field.localizedTitle, message: e.localizedDescription)
            completion(false, e)
            return
        }
        catch {
            self.presentErrorAlert(title: nil, message: error.localizedDescription)
            completion(false, error)
            return
        }
        
        
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
                    self.presentErrorAlert(title: nil, message: error?.localizedDescription ?? NSLocalizedString("infection.report.gathering_data.error", comment: ""))
                }
                
                completion(false, error)
                return
            }
            
            let keys = exposureInfo.keys

            let alert = UIAlertController(title: NSLocalizedString("infection.report.submit.title", comment: ""), message: NSLocalizedString("infection.report.submit.message", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("submit", comment: ""), style: .destructive, handler: { action in
                
                self.submitReport(keys: keys, completion: completion)
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension SubmitInfectionViewController {
    func assertFormIsValid() throws {
        let containers = self.stackView.arrangedSubviews.compactMap { $0 as? SubmitInfectionFormContainerView }
        
        var containersByName: [String: SubmitInfectionFormContainerView] = [:]
        
        containers.forEach { containersByName[$0.formName] = $0 }

        for field in self.config.sortedFields {
            guard let container = containersByName[field.formName] else {
                // Perhaps this should throw an error, but it's not the user's fault
                continue
            }
            
            guard let formField = container.formField else {
                if field.required {
                    throw FormValidationError(field: field, errorType: .valueMissing)
                }
                else {
                    continue
                }
            }
            
            guard formField.isValid else {
                throw FormValidationError(field: field, errorType: .valueInvalid)
            }
        }
        
        // Form is valid here, don't throw
    }
    
    var gatherFormData: InfectedKeysFormData {
        
        let containers = self.stackView.arrangedSubviews.compactMap { $0 as? SubmitInfectionFormContainerView }
        
        let fields = containers.compactMap { $0.formField }
        
        return InfectedKeysFormData(fields: fields)
    }
}

extension SubmitInfectionViewController {
    func submitReport(keys: [ENTemporaryExposureKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        let formData = self.gatherFormData
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.submitting.title", comment: ""), message: NSLocalizedString("infection.report.submitting.message", comment: ""), preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)

        DataManager.shared.submitReport(formData: formData, keys: keys) { success, error in
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    if success {
                        completion(success, error)
                    }
                    else {
                        self.presentErrorAlert(title: nil, message: error?.localizedDescription ?? NSLocalizedString("infection.report.submit.error", comment: "" ))
                        completion(false, error)
                    }
                }
            }
        }
    }
}
