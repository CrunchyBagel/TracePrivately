//
//  ExposedViewController.swift
//  TracePrivately
//
//  Created by Quentin Zervaas on 17/4/20.
//  Copyright © 2020 Quentin Zervaas. All rights reserved.
//

import UIKit

class ExposedViewController: UITableViewController {

    enum RowType {
        case contact(CTContactInfo)
        case nextSteps
    }
    
    struct Section {
        let header: String?
        let footer: String?
        
        let rows: [RowType]
    }
    
    var sections: [Section] = []

    var exposureContacts: [CTContactInfo] = []
    
    lazy var timeFormatter: DateFormatter = {
        let ret = DateFormatter()
        ret.dateStyle = .medium
        ret.timeStyle = .medium
        
        return ret
    }()
    
    lazy var durationFormatter: DateComponentsFormatter = {
        let ret = DateComponentsFormatter()
        ret.allowedUnits = [ .hour, .minute, .second ]
        ret.unitsStyle = .short
        ret.collapsesLargestUnit = true
        
        return ret
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Exposed"
        
        if self.exposureContacts.count == 0 {
            self.sections = [
                Section(header: nil, footer: "We have not detected exposure to COVID-19.", rows: [])
            ]
        }
        else {
            self.sections = [
                Section(header: nil, footer: "We believe you have come in contact with COVID-19:", rows: []),
                Section(header: nil, footer: nil, rows: self.exposureContacts.map { .contact($0)} ),
                Section(header: nil, footer: nil, rows: [ .nextSteps ])
            ]
        }
    }
}

extension ExposedViewController {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let rowType = self.sections[indexPath.section].rows[indexPath.row]
        
        switch rowType {
        case .contact(let contact):
            cell.textLabel?.text = self.timeFormatter.string(from: contact.timestamp)
            cell.detailTextLabel?.text = self.durationFormatter.string(from: contact.duration)
            cell.selectionStyle = .none
            cell.accessoryType = .none
            
        case .nextSteps:
            cell.textLabel?.text = "Next Steps"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
