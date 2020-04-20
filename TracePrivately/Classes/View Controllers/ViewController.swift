//
//  ViewController.swift
//  TracePrivately
//

import UIKit

class ViewController: UITableViewController {

    struct Cells {
        static let standard = "Cell"
        static let exposed = "ExposedCell"
        static let infected = "InfectedCell"
    }
    
    struct Segues {
        static let exposed = "ExposedSegue"
        static let submitInfection = "SubmitInfectionSegue"
        static let viewInfection = "ViewInfectionSegue"
    }
    
    enum RowType {
        case startStopTracing
        case startStopExposureChecking
        case markAsInfected
        case infectionConfirmed
        case exposureConfirmed
    }
    
    struct Section {
        let header: String?
        let footer: String?
        
        let rows: [RowType]
    }
    
    var tracingStatusError: Error?
    var tracingStatus: CTManagerState = .unknown
    
    var sections: [Section] = []
    
    fileprivate var isDeterminingState = false
    fileprivate var stateGetRequest: CTStateGetRequest?
    
    fileprivate var isSettingState = false
    fileprivate var stateSetRequest: CTStateSetRequest?
    
    fileprivate var isEnablingExposureChecking = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("app.title", comment: "")
        
        var sections: [Section] = [
            Section(
                header: NSLocalizedString("tracing.title", comment: ""),
                footer: NSLocalizedString("tracing.message", comment: ""),
                rows: [ .startStopTracing ]
            ),
            Section(
                header: nil,
                footer: NSLocalizedString("exposure.turn_on.message", comment: ""),
                rows: [ .startStopExposureChecking ]
            )
        ]
        
        let status = self.diseaseStatus
        
        if status != .infected {
            sections.append(self.createSubmitInfectionSection())
        }
            
        sections.append(Section(
            header: NSLocalizedString("about.title", comment: ""),
            footer: NSLocalizedString("about.message", comment: ""),
            rows: []
        ))
        
        let cells: [RowType]
        
        switch self.diseaseStatus {
        case .infected: cells = [ .infectionConfirmed ]
        case .exposed: cells = [ .exposureConfirmed ]
        case .nothingDetected: cells = []
        }

        if cells.count > 0 {
            sections.insert(Section(header: nil, footer: nil, rows: cells), at: 0)
        }
        
        self.sections = sections
        
        self.refreshTracingState()
        
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: DataManager.exposureContactsUpdatedNotification, object: nil, queue: .main) { _ in
            self.updateDiseaseStatusCell()
        }
        
        nc.addObserver(forName: DataManager.infectionsUpdatedNotification, object: nil, queue: .main) { _ in
            self.updateDiseaseStatusCell()
        }
    }
    
    func createSubmitInfectionSection() -> Section {
        return Section(
            header: NSLocalizedString("infection.title", comment: ""),
            footer: nil,
            rows: [ .markAsInfected ]
        )
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.exposed:
            break
            
        default:
            super.prepare(for: segue, sender: sender)
        }
    }
}

extension ViewController {
    enum DiseaseStatus {
        case nothingDetected
        case exposed
        case infected
    }
    
    var diseaseStatus: DiseaseStatus {
        let context = DataManager.shared.persistentContainer.viewContext

        let exposureRequest = ExposureFetchRequest(includeStatuses: [ .detected ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        let numContacts = (try? context.count(for: exposureRequest.fetchRequest)) ?? 0
        
        let infectionRequest = InfectionFetchRequest(minDate: nil, includeStatuses: [ .submitted ])
        let numInfections = (try? context.count(for: infectionRequest.fetchRequest)) ?? 0

        if numContacts > 0 {
            return .exposed
        }
        else if numInfections > 0 {
            return .infected
        }
        else {
            return .nothingDetected
        }
    }

    // This would be far simpler using UITableViewDiffableDataSource, but it's not backwards compatible
    func updateDiseaseStatusCell() {
        let infectionIndexPath = self.indexPath(rowType: .infectionConfirmed)
        let exposureIndexPath = self.indexPath(rowType: .exposureConfirmed)
        
        var insertSections = IndexSet()
        var deleteSections = IndexSet()
        var reloadSections = IndexSet()
        
        var showInfectedRow = true
        
        switch self.diseaseStatus {
        case .infected:
            showInfectedRow = false
            
            let section = Section(header: nil, footer: nil, rows: [ .infectionConfirmed ])

            if infectionIndexPath != nil {
                print(">>>> A")
                // Nothing to do
            }
            else if let exposureIndexPath = exposureIndexPath {
                print(">>>> B")
                self.sections[exposureIndexPath.section] = section
                reloadSections.insert(exposureIndexPath.section)
            }
            else {
                print(">>>> C")
                let sectionNumber = 0

                self.sections.insert(section, at: sectionNumber)
                insertSections.insert(sectionNumber)
            }

        case .exposed:
            let section = Section(header: nil, footer: nil, rows: [ .exposureConfirmed ])

            if exposureIndexPath != nil {
                print(">>>> D")
                // Nothing to do
            }
            else if let infectionIndexPath = infectionIndexPath {
                print(">>>> E")

                self.sections[infectionIndexPath.section] = section
                reloadSections.insert(infectionIndexPath.section)
            }
            else {
                print(">>>> F")
                let sectionNumber = 0
                self.sections.insert(section, at: sectionNumber)
                insertSections.insert(sectionNumber)
            }

        case .nothingDetected:
            print(">>>> G")
            let indexPath = infectionIndexPath ?? exposureIndexPath
            
            if let indexPath = indexPath {
                self.sections.remove(at: indexPath.section)
                deleteSections.insert(indexPath.section)
            }
        }
        
        if !insertSections.isEmpty || !deleteSections.isEmpty || !reloadSections.isEmpty {
            self.tableView.beginUpdates()
            
            if !insertSections.isEmpty {
                self.tableView.insertSections(insertSections, with: .automatic)
            }
            
            if !deleteSections.isEmpty {
                self.tableView.deleteSections(deleteSections, with: .automatic)
            }
            
            if !reloadSections.isEmpty {
                self.tableView.reloadSections(reloadSections, with: .automatic)
            }
            
            self.tableView.endUpdates()
        }

        if let indexPath = self.indexPath(rowType: .markAsInfected) {
            if !showInfectedRow {
                print(">>>> H")
                self.sections.remove(at: indexPath.section)
                self.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
                deleteSections.insert(indexPath.section)
            }
        }
        else {
            if showInfectedRow {
                print(">>>> I")
                let section = self.sections.count - 1
                self.sections.insert(self.createSubmitInfectionSection(), at: section)
                self.tableView.insertSections(IndexSet(integer: section), with: .automatic)
            }
        }
    }
}

extension ViewController {
    func refreshTracingState() {
        self.stateGetRequest?.invalidate()
        
        self.isDeterminingState = true
        
        let request = CTStateGetRequest()
        request.completionHandler = { error in
            // In this example the request is running on main queue anyway, but I've put the dispatch in anyway
            DispatchQueue.main.async {
                self.tracingStatusError = error
                self.tracingStatus = request.state
                
                self.isDeterminingState = false
                
                var indexPaths: [IndexPath] = []
                
                if let indexPath = self.indexPath(rowType: .startStopTracing) {
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

// TODO: Move this to ContactTracingManager
extension ViewController {
    func startTracing() {
        self.setState(state: .on)
    }
    
    func stopTracing() {
        self.setState(state: .off)
    }

    private func setState(state: CTManagerState) {
        self.stateSetRequest?.invalidate()
        
        self.isSettingState = true
        
        if let cell = self.visibleCell(rowType: .startStopTracing) {
            self.updateStartStopTracingCell(cell: cell)
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
                    self.tracingStatus = state
                }
                
                self.isSettingState = false

                var indexPaths: [IndexPath] = []
                
                if let indexPath = self.indexPath(rowType: .startStopTracing) {
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
    func updateStartStopTracingCell(cell: UITableViewCell) {
        
        let accessoryType: UITableViewCell.AccessoryType
        
        switch self.tracingStatus {
        case .off:
            cell.textLabel?.text = NSLocalizedString("tracing.start.title", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("tracing.available", comment: "")
            accessoryType = .disclosureIndicator

        case .on:
            cell.textLabel?.text = NSLocalizedString("tracing.stop.title", comment: "")
            cell.detailTextLabel?.text = nil
            accessoryType = .none
            
        case .unknown:
            cell.textLabel?.text = NSLocalizedString("tracing.start.title", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("tracing.not_available", comment: "")
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
        
        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {

        case .startStopTracing:
            let cell = tableView.dequeueReusableCell(withIdentifier: Cells.standard, for: indexPath)
            self.updateStartStopTracingCell(cell: cell)
            
            return cell
            
        case .startStopExposureChecking:
            let cell = tableView.dequeueReusableCell(withIdentifier: Cells.standard, for: indexPath)

            cell.detailTextLabel?.text = nil
            
            self.updateCheckExposureIndicator(cell: cell)
            
            return cell
            
        case .markAsInfected:
            let cell = tableView.dequeueReusableCell(withIdentifier: Cells.standard, for: indexPath)

            cell.textLabel?.text = String(format: NSLocalizedString("infection.report.title", comment: ""), Disease.current.localizedTitle)
            
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            
            return cell
            
        case .infectionConfirmed:
            let cell = tableView.dequeueReusableCell(withIdentifier: Cells.infected, for: indexPath)

            cell.textLabel?.text = NSLocalizedString("infection.infected.title", comment: "")
            cell.detailTextLabel?.text = String(format: NSLocalizedString("infection.infected.message", comment: ""), Disease.current.localizedTitle)
            cell.accessoryType = .disclosureIndicator

            return cell

        case .exposureConfirmed:
            let cell = tableView.dequeueReusableCell(withIdentifier: Cells.exposed, for: indexPath)

            cell.textLabel?.text = NSLocalizedString("exposure.exposed.title", comment: "")
            cell.detailTextLabel?.text = String(format: NSLocalizedString("exposure.exposed.message", comment: ""), Disease.current.localizedTitle)
            cell.accessoryType = .disclosureIndicator

            return cell
        }
    }
    
    func updateCheckExposureIndicator(cell: UITableViewCell) {
        if self.isEnablingExposureChecking {
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
            cell.accessoryType = .none
        }

        if ContactTraceManager.shared.exposureCheckingEnabled {
            cell.textLabel?.text = NSLocalizedString("exposure.turn_off.title", comment: "")
        }
        else {
            cell.textLabel?.text = NSLocalizedString("exposure.turn_on.title", comment: "")
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
            
        case .startStopTracing:
            tableView.deselectRow(at: indexPath, animated: true)
            
            switch self.tracingStatus {
            case .unknown:
                let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: NSLocalizedString("tracing.start.error", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
            case .off:
                let alert = UIAlertController(title: NSLocalizedString("tracing.start.title", comment: ""), message: NSLocalizedString("tracing.start.message", comment: ""), preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("tracing.start.button.title", comment: ""), style: .destructive, handler: { action in
                   
                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)

                    self.startTracing()
                    
                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
                
                self.present(alert, animated: true, completion: nil)
                
            case .on:
                let alert = UIAlertController(title: NSLocalizedString("tracing.stop.title", comment: ""), message: NSLocalizedString("tracing.stop.message", comment: ""), preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("tracing.stop.button.title", comment: ""), style: .destructive, handler: { action in

                    let haptics = UINotificationFeedbackGenerator()
                    haptics.notificationOccurred(.success)
                    
                    self.stopTracing()

                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
            
        case .startStopExposureChecking:
            tableView.deselectRow(at: indexPath, animated: true)
            
            if self.isEnablingExposureChecking {
                // Not possible
            }
            else if ContactTraceManager.shared.exposureCheckingEnabled {
                self.turnOffExposureChecking()
            }
            else {
                self.turnOnExposureChecking()
            }
            
        case .exposureConfirmed:
            tableView.deselectRow(at: indexPath, animated: true)
            self.performSegue(withIdentifier: Segues.exposed, sender: nil)
            
        case .infectionConfirmed:
            tableView.deselectRow(at: indexPath, animated: true)
            self.performSegue(withIdentifier: Segues.viewInfection, sender: nil)

        case .markAsInfected:
            tableView.deselectRow(at: indexPath, animated: true)
            self.performSegue(withIdentifier: Segues.submitInfection, sender: nil)
            
        }
    }
}

extension ViewController {
    func turnOffExposureChecking() {
        ContactTraceManager.shared.stopExposureChecking()
        self.isEnablingExposureChecking = false
        
        if let cell = self.visibleCell(rowType: .startStopExposureChecking) {
            self.updateCheckExposureIndicator(cell: cell)
        }
    }
    
    func turnOnExposureChecking() {
        guard !self.isEnablingExposureChecking else {
            return
        }
        
        guard !ContactTraceManager.shared.exposureCheckingEnabled else {
            return
        }
        
        self.isEnablingExposureChecking = true
        
        if let cell = self.visibleCell(rowType: .startStopExposureChecking) {
            self.updateCheckExposureIndicator(cell: cell)
        }
        
        ContactTraceManager.shared.startExposureChecking { error in
            DispatchQueue.main.async {
                self.isEnablingExposureChecking = false
                
                if let cell = self.visibleCell(rowType: .startStopExposureChecking) {
                    self.updateCheckExposureIndicator(cell: cell)
                }

                if let error = error {
                    let alert = UIAlertController(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    
                    self.present(alert, animated: true, completion: nil)
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
