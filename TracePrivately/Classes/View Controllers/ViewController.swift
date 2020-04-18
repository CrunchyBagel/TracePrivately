//
//  ViewController.swift
//  TracePrivately
//

import UIKit

// TODO: Remember when the user has been exposed so they can subsequently confirm or deny an infection

class ViewController: UITableViewController {

    struct Cells {
        static let standard = "Cell"
    }
    
    struct Segues {
        static let exposed = "ExposedSegue"
    }
    
    enum RowType {
        case trackingState
        case startStopTracking
        case checkIfExposed
        case markAsInfected
    }
    
    struct Section {
        let header: String?
        let footer: String?
        
        let rows: [RowType]
    }
    
    var trackingStatusError: Error?
    var trackingStatus: CTManagerState = .unknown
    
    var sections: [Section] = []
    
    fileprivate var isDeterminingState = false
    fileprivate var stateGetRequest: CTStateGetRequest?
    
    fileprivate var isSettingState = false
    fileprivate var stateSetRequest: CTStateSetRequest?
    
    fileprivate var isCheckingExposure = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.title = NSLocalizedString("app.title", comment: "")
        
        self.sections = [
            Section(
                header: NSLocalizedString("about.title", comment: ""),
                footer: NSLocalizedString("about.message", comment: ""),
                rows: []
            ),
            Section(
                header: NSLocalizedString("tracking.title", comment: ""),
                footer: nil,
                rows: [ .trackingState, .startStopTracking ]
            ),
            Section(
                header: NSLocalizedString("infection.title", comment: ""),
                footer: nil,
                rows: [ .markAsInfected ]
            ),
            Section(
                header: NSLocalizedString("exposure.title", comment: ""),
                footer: NSLocalizedString("exposure.message", comment: ""),
                rows: [ .checkIfExposed ]
            )
        ]
        
        self.refreshTrackingState()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.exposed:
            guard let nc = segue.destination as? UINavigationController, let vc = nc.viewControllers.first as? ExposedViewController else {
                return
            }
            
            if let contacts = sender as? [CTContactInfo] {
                vc.exposureContacts = contacts
            }
            
        default:
            super.prepare(for: segue, sender: sender)
        }
    }
}

extension ViewController {
    func refreshTrackingState() {
        self.stateGetRequest?.invalidate()
        
        self.isDeterminingState = true
        
        let request = CTStateGetRequest()
        request.completionHandler = { error in
            // In this example the request is running on main queue anyway, but I've put the dispatch in anyway
            DispatchQueue.main.async {
                self.trackingStatusError = error
                self.trackingStatus = request.state
                
                self.isDeterminingState = false
                
                var indexPaths: [IndexPath] = []
                
                if let indexPath = self.indexPath(rowType: .trackingState) {
                    indexPaths.append(indexPath)
                }

                if let indexPath = self.indexPath(rowType: .startStopTracking) {
                    indexPaths.append(indexPath)
                }
            
                if indexPaths.count > 0 {
                    self.tableView.reloadRows(at: indexPaths, with: .automatic)
                }
            }
        }
        
        self.stateGetRequest = request
        
        request.perform()
    }
}

extension ViewController {
    func startTracking() {
        self.setState(state: .on)
    }
    
    func stopTracking() {
        self.setState(state: .off)
    }

    private func setState(state: CTManagerState) {
        self.stateSetRequest?.invalidate()
        
        self.isSettingState = true
        
        if let cell = self.visibleCell(rowType: .startStopTracking) {
            self.updateStartStopTrackingCell(cell: cell)
        }
        
        let request = CTStateSetRequest()
        request.state = state
        request.completionHandler = { error in
            DispatchQueue.main.async {
                if let error = error {
                    let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler: nil))
                }
                else {
                    self.trackingStatus = state
                }
                
                self.isSettingState = false

                var indexPaths: [IndexPath] = []
                
                if let indexPath = self.indexPath(rowType: .trackingState) {
                    indexPaths.append(indexPath)
                }

                if let indexPath = self.indexPath(rowType: .startStopTracking) {
                    indexPaths.append(indexPath)
                }
                
                if indexPaths.count > 0 {
                    self.tableView.reloadRows(at: indexPaths, with: .automatic)
                }
            }
        }
        
        self.stateSetRequest = request
        
        request.perform()
    }
}

extension ViewController {
    func updateStartStopTrackingCell(cell: UITableViewCell) {
        
        let accessoryType: UITableViewCell.AccessoryType
        
        switch self.trackingStatus {
        case .off:
            cell.textLabel?.text = NSLocalizedString("tracking.start.title", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("tracking.available", comment: "")
            accessoryType = .disclosureIndicator

        case .on:
            cell.textLabel?.text = NSLocalizedString("tracking.stop.title", comment: "")
            cell.detailTextLabel?.text = nil
            accessoryType = .none
            
        case .unknown:
            cell.textLabel?.text = NSLocalizedString("tracking.start.title", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("tracking.not_available", comment: "")
            accessoryType = .none
        }
        
        if self.isSettingState {
            let style: UIActivityIndicatorView.Style
            
            if #available(iOS 13.0, *) {
                style = .medium
            } else {
                style = .gray
            }
            
            let indicator = UIActivityIndicatorView(style: style)
            indicator.startAnimating()
            cell.accessoryView = indicator
        }
        else {
            cell.accessoryView = nil
            cell.accessoryType = accessoryType
        }
    }
}

extension ViewController {
    func visibleCell(rowType: RowType) -> UITableViewCell? {
        guard let indexPath = self.indexPath(rowType: rowType) else {
            return nil
        }
        
        return self.tableView.cellForRow(at: indexPath)
    }
    
    func indexPath(rowType: RowType) -> IndexPath? {
        for (s, section) in self.sections.enumerated() {
            for (r, row) in section.rows.enumerated() {
                if row == rowType {
                    return IndexPath(row: r, section: s)
                }
            }
        }
        
        return nil
    }
}

extension ViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].header
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.sections[section].footer
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cells.standard, for: indexPath)
        
        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {
        case .trackingState:
            cell.textLabel?.text = NSLocalizedString("tracking.state.title", comment: "")
            
            if let error = self.trackingStatusError {
                cell.detailTextLabel?.text = error.localizedDescription
            }
            else {
                cell.detailTextLabel?.text = self.trackingStatus.localizedTitle
            }
            
            if self.isDeterminingState {
                let style: UIActivityIndicatorView.Style
                
                if #available(iOS 13.0, *) {
                    style = .medium
                } else {
                    style = .gray
                }

                let indicator = UIActivityIndicatorView(style: style)
                indicator.startAnimating()
                cell.accessoryView = indicator
            }
            else {
                cell.accessoryView = nil
            }
            
            self.updateGetStateIndicator(cell: cell)
            
        case .startStopTracking:
            self.updateStartStopTrackingCell(cell: cell)
            
        case .checkIfExposed:
            cell.textLabel?.text = NSLocalizedString("exposure.check.title", comment: "")
            cell.detailTextLabel?.text = nil
            
            self.updateCheckExposureIndicator(cell: cell)
            
        case .markAsInfected:
            
            cell.textLabel?.text = String(format: NSLocalizedString("infection.report.title", comment: ""), Disease.current.localizedTitle)
            
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func updateCheckExposureIndicator(cell: UITableViewCell) {
        if self.isCheckingExposure {
            let style: UIActivityIndicatorView.Style
            
            if #available(iOS 13.0, *) {
                style = .medium
            } else {
                style = .gray
            }

            let indicator = UIActivityIndicatorView(style: style)
            indicator.startAnimating()
            cell.accessoryView = indicator
        }
        else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }
    }
    
    private func updateGetStateIndicator(cell: UITableViewCell) {
        if self.isDeterminingState {
            let style: UIActivityIndicatorView.Style
            
            if #available(iOS 13.0, *) {
                style = .medium
            } else {
                style = .gray
            }

            let indicator = UIActivityIndicatorView(style: style)
            indicator.startAnimating()
            cell.accessoryView = indicator
        }
        else {
            cell.accessoryView = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {
        case .trackingState:
            self.refreshTrackingState()
            tableView.deselectRow(at: indexPath, animated: true)
            
            if let cell = tableView.cellForRow(at: indexPath) {
                self.updateGetStateIndicator(cell: cell)
            }
            
        case .startStopTracking:
            tableView.deselectRow(at: indexPath, animated: true)
            
            switch self.trackingStatus {
            case .unknown:
                let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: NSLocalizedString("tracking.start.error", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
            case .off:
                let alert = UIAlertController(title: NSLocalizedString("tracking.start.title", comment: ""), message: NSLocalizedString("tracking.start.message", comment: ""), preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("tracking.start.button.title", comment: ""), style: .destructive, handler: { action in
                   
                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)

                    self.startTracking()
                    
                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
                
                self.present(alert, animated: true, completion: nil)
                
            case .on:
                let alert = UIAlertController(title: NSLocalizedString("tracking.stop.title", comment: ""), message: NSLocalizedString("tracking.stop.message", comment: ""), preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("tracking.stop.button.title", comment: ""), style: .destructive, handler: { action in

                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)
                    
                    self.stopTracking()

                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
            
        case .checkIfExposed:
            tableView.deselectRow(at: indexPath, animated: true)
            self.beginExposureWorkflow()
            
        case .markAsInfected:
            
            tableView.deselectRow(at: indexPath, animated: true)

            let alert = UIAlertController(title: NSLocalizedString("infection.report.confirm.title", comment: ""), message: NSLocalizedString("infection.report.confirm.message", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .destructive, handler: { action in
                self.beginInfectionWorkflow()
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ViewController {
    func beginInfectionWorkflow() {
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.gathering_data.title", comment: ""), message: nil, preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)

        let request = CTSelfTracingInfoRequest()
        
        request.completionHandler = { info, error in
            /// I'm not exactly sure what the difference is between dailyTrackingKeys being nil or empty. I would assume it should never be nil, and only be empty if tracking has not been enabled. Hopefully this becomes clearer with more documentation.
            
            guard let keys = info?.dailyTracingKeys else {
                let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error?.localizedDescription ?? NSLocalizedString("infection.report.gathering_data.error", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                
                self.dismiss(animated: true) {
                    self.present(alert, animated: true, completion: nil)
                }
                
                return
            }
            
            guard keys.count > 0 else {
                let alert = UIAlertController(title: NSLocalizedString("infection.report.gathering.empty.title", comment: ""), message: NSLocalizedString("infection.report.gathering.empty.message", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))

                self.dismiss(animated: true) {
                    self.present(alert, animated: true, completion: nil)
                }
                
                return
            }
            
            self.dismiss(animated: true) {
                let alert = UIAlertController(title: NSLocalizedString("infection.report.submit.title", comment: ""), message: NSLocalizedString("infection.report.submit.message", comment: ""), preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: NSLocalizedString("submit", comment: ""), style: .destructive, handler: { action in
                    
                    self.submitKeys(keys: keys)
                    
                }))
                
                self.present(alert, animated: true, completion: nil)
            }
        }

        request.perform()
    }
    
    // TODO: Make it super clear to the user if an error occurred, so they have an opportunity to submit again
    func submitKeys(keys: [CTDailyTracingKey]) {
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("infection.report.submitting.title", comment: ""), message: NSLocalizedString("infection.report.submitting.message", comment: ""), preferredStyle: .alert)

        self.present(loadingAlert, animated: true, completion: nil)
        
        let context = DataManager.shared.persistentContainer.newBackgroundContext()
        
        context.perform {
            let entity = LocalInfectionEntity(context: context)
            entity.dateAdded = Date()
            entity.status = "P"
            
            try? context.save()
        
            KeyServer.shared.submitInfectedKeys(keys: keys) { success, error in
                
                if success {
                    context.perform {
                        entity.status = "S" // Submitted
                        
                        for key in keys {
                            let keyEntity = LocalInfectionKeyEntity(context: context)
                            keyEntity.infectedKey = key.keyData
                            keyEntity.infection = entity
                        }

                        try? context.save()

                        DispatchQueue.main.async {
                            self.dismiss(animated: true) {
                                
                                if success {
                                    let alert = UIAlertController(title: NSLocalizedString("infection.report.submitted.title", comment: ""), message: NSLocalizedString("infection.report.submitted.message", comment: ""), preferredStyle: .alert)
                                    
                                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                                    
                                    self.present(alert, animated: true, completion: nil)
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
        }
    }
}

extension ViewController {
    func beginExposureWorkflow() {
        guard !self.isCheckingExposure else {
            return
        }

        let session = CTExposureDetectionSession()
        
        // This prompts a permission dialog
        session.activateWithCompletion { error in
            if let error = error {
                DispatchQueue.main.async {
                    var showAlert = true
                    
                    if let error = error as? CTError {
                        if error == .permissionDenied {
                            showAlert = false
                        }
                    }
                    
                    if showAlert {
                        let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                }
                
                return
            }


            DispatchQueue.main.async {
                self.isCheckingExposure = true
                
                if let cell = self.visibleCell(rowType: .checkIfExposed) {
                    self.updateCheckExposureIndicator(cell: cell)
                }

                // Permission allowed, now we can start exposure detection
                
                // 1. Retrieve infected keys from server
                // 2. Add them to addPositiveDiagnosis
                // 3. Finish diagnosis
                // 4. Display infection contact summary
                
                // TODO: This isn't splitting to maxKeyCount yet
                DataManager.shared.allInfectedKeys { keys, error in
                    guard let keys = keys else {
                        DispatchQueue.main.async {
                            self.isCheckingExposure = false

                            if let cell = self.visibleCell(rowType: .checkIfExposed) {
                                self.updateCheckExposureIndicator(cell: cell)
                            }
                        }

                        return
                    }

                    session.addPositiveDiagnosisKey(inKeys: keys) { error in
                        guard error == nil else {
                            DispatchQueue.main.async {
                                self.isCheckingExposure = false

                                if let cell = self.visibleCell(rowType: .checkIfExposed) {
                                    self.updateCheckExposureIndicator(cell: cell)
                                }
                            }

                            return
                        }

                        session.finishedPositiveDiagnosisKeys { summary, error in
                            guard let summary = summary else {
                                DispatchQueue.main.async {
                                    self.isCheckingExposure = false

                                    if let cell = self.visibleCell(rowType: .checkIfExposed) {
                                        self.updateCheckExposureIndicator(cell: cell)
                                    }
                                }

                                return
                            }
                            
                            if summary.matchedKeyCount == 0 {
                                DispatchQueue.main.async {
                                    
                                    let message = String(format: NSLocalizedString("exposure.none.message", comment: ""), Disease.current.localizedTitle)
                                    
                                    let alert = UIAlertController(title: "Great News", message: message, preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)

                                    self.isCheckingExposure = false
                                    
                                    if let cell = self.visibleCell(rowType: .checkIfExposed) {
                                        self.updateCheckExposureIndicator(cell: cell)
                                    }
                                }
                                
                                return
                            }

                            session.getContactInfoWithHandler { info, error in
                                guard let info = info, info.count > 0 else {
                                    return
                                }
                                
                                DispatchQueue.main.async {
                                    self.isCheckingExposure = false
                                    
                                    if let cell = self.visibleCell(rowType: .checkIfExposed) {
                                        self.updateCheckExposureIndicator(cell: cell)
                                    }
                                    
                                    self.performSegue(withIdentifier: Segues.exposed, sender: info)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension CTManagerState {
    var localizedTitle: String {
        switch self {
        case .unknown: return NSLocalizedString("unknown", comment: "")
        case .on: return NSLocalizedString("on", comment: "")
        case .off: return NSLocalizedString("off", comment: "")
        }
    }
}
