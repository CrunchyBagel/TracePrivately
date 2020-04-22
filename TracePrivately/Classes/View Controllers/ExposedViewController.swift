//
//  ExposedViewController.swift
//  TracePrivately
//

import UIKit
import CoreData

class ExposedViewController: UICollectionViewController {

    struct Cells {
        static let nextSteps = "NextStepsCell"
        static let contact = "ExposureCell"
        static let intro = "IntroCell"
    }

    enum CellType {
        case contact(CTContactInfo)
        case intro(String)
        case nextSteps
    }
    
    struct Section {
        let cells: [CellType]
    }
    
    var sections: [Section] = []

    lazy var timeFormatter: DateFormatter = {
        let ret = DateFormatter()
        ret.dateStyle = .long
        ret.timeStyle = .short
        
        return ret
    }()
    
    lazy var durationFormatter: DateComponentsFormatter = {
        let ret = DateComponentsFormatter()
        ret.allowedUnits = [ .day, .hour, .minute ]
        ret.unitsStyle = .abbreviated
        ret.zeroFormattingBehavior = .dropLeading
        ret.maximumUnitCount = 2
        
        return ret
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("exposure.exposed.title", comment: "")
        
        // Swipe down to dismiss also available on iOS 13+
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(Self.doneTapped(_:)))
        self.navigationItem.leftBarButtonItem = button

        let request = ExposureFetchRequest(includeStatuses: [ .detected ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        
        let context = DataManager.shared.persistentContainer.viewContext
        
        let entities: [ExposureContactInfoEntity]
        
        do {
            entities = try context.fetch(request.fetchRequest)
        }
        catch {
            entities = []
        }
        
        let contacts: [CTContactInfo] = entities.compactMap { $0.contactInfo }

        if contacts.count == 0 {
            let title = String(format: NSLocalizedString("exposure.none.message", comment: ""), Disease.current.localizedTitle)
            self.sections = [
                Section(cells: [
                    .intro(title)
                ])
            ]
        }
        else {
            
            let title = String(format: NSLocalizedString("exposure.exposed.message", comment: "") , Disease.current.localizedTitle)

            self.sections = [
                Section(cells: [ .intro(title) ]),
                Section(cells: contacts.map { .contact($0)}),
                Section(cells: [ .nextSteps ])
            ]
        }
    }
    
    @objc func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ExposedViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sections.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.sections[section].cells.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let rowType = self.sections[indexPath.section].cells[indexPath.row]
        
        switch rowType {
        case .intro(let str):
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cells.intro, for: indexPath)
            
            if let cell = cell as? ExposedIntroCell {
                cell.label.text = str
            }
            
            return cell
            
        case .contact(let contact):

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cells.contact, for: indexPath)
                
            if let cell = cell as? ExposedContactCell {

                cell.timeLabel.text = self.timeFormatter.string(from: contact.date)

                if let str = self.durationFormatter.string(from: contact.duration) {
                    cell.durationLabel?.text = String(format: NSLocalizedString("exposure.times.duration", comment: ""), str)
                }
                else {
                    cell.durationLabel?.text = nil
                }
                
                if contact.duration < 600 {
                    cell.contentView.backgroundColor = UIColor.systemOrange
                }
                else {
                    cell.contentView.backgroundColor = UIColor.systemRed
                }
            }
            
            return cell

        case .nextSteps:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cells.nextSteps, for: indexPath)
            
            if let cell = cell as? ExposedNextStepsCell {
                cell.label.text = NSLocalizedString("exposure.next_steps.title", comment: "")
            }
            
            return cell
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let rowType = self.sections[indexPath.section].cells[indexPath.row]
        
        switch rowType {
        case .intro:
            break
            
        case .contact:
            let alert = UIAlertController(title: "Exposure Info", message: "TODO", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
            
            self.present(alert, animated: true, completion: nil)

        case .nextSteps:
            let alert = UIAlertController(title: NSLocalizedString("exposure.next_steps.title", comment: ""), message: NSLocalizedString("exposure.next_steps.message", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        }
        
    }
}

extension ExposedViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        if section == 0 {
            return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        }
        else {
            return UIEdgeInsets(top: 0, left: 20, bottom: 20, right: 20)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let insets = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        
        let width = collectionView.frame.size.width - insets.left - insets.right
        
        let rowType = self.sections[indexPath.section].cells[indexPath.row]
        
        switch rowType {
        case .contact:
            return CGSize(width: width, height: 72)

        case .intro(let str):
            let font = UIFont.preferredFont(forTextStyle: .body)
            let size = font.sizeOfString(string: str, constrainedToWidth: width)

            return CGSize(width: width, height: size.height)
            
        case .nextSteps:
            return CGSize(width: width, height: 52)
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
}

class ExposedIntroCell: UICollectionViewCell {
    @IBOutlet var label: UILabel!
}

class ExposedNextStepsCell: UICollectionViewCell {
    @IBOutlet var label: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.cornerRadius = 8
    }
}

class ExposedContactCell: UICollectionViewCell {
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var durationLabel: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.cornerRadius = 8
    }
}

