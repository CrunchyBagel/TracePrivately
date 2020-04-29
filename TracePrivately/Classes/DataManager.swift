//
//  DataManager.swift
//  TracePrivately
//

import CoreData
import ExposureNotification

class DataManager {
    static let shared = DataManager()
    

    private init() {
        
    }
    
    static let exposureContactsUpdatedNotification = Notification.Name("exposureContactsUpdatedNotification")
    static let infectionsUpdatedNotification = Notification.Name("infectionsUpdatedNotification")

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "TracePrivately")
        
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            
            if #available(iOS 11.0, *) {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            
            if let url = storeDescription.url {
                print("Core Data URL: \(url.relativeString)")
            }

            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

extension DataManager {
    func deleteLocalInfections(completion: @escaping (Swift.Error?) -> Void) {
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LocalInfectionEntity.fetchRequest()
                
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
                
                try context.save()
                
                NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
            }
            catch {
                completion(nil)
            }
        }
    }
    
    // TODO: Refactor this a bit more neatly
    struct TemporaryExposureKey {
        let keyData: Data
        let rollingStartNumber: ENIntervalNumber
        // TODO: Support risk level
    }
    
    struct ExposureInfo {
        let attenuationValue: ENAttenuation
        let date: Date
        let duration: TimeInterval
        let totalRiskScore: ENRiskScore
        let transmissionRiskLevel: ENRiskLevel
    }


    func saveInfectedKeys(keys: [TemporaryExposureKey], completion: @escaping (_ numNewKeys: Int, _ error: Swift.Error?) -> Void) {
        
        guard keys.count > 0 else {
            completion(0, nil)
            return
        }
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            // Check incoming keys against submitted keys to see if the
            // submitted infection has been approved
            
            var localInfectionsUpdated = false
            
            do {
                let fetchRequest: NSFetchRequest<LocalInfectionEntity> = LocalInfectionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "status != %@", InfectionStatus.submittedApproved.rawValue)
                
                let entities = try context.fetch(fetchRequest)
                
                let keyData: Set<Data> = Set(keys.map { $0.networkData })
                
                var approvedEntities: [LocalInfectionEntity] = []
                
                for entity in entities {
                    guard let keysSet = entity.infectedKey else {
                        continue
                    }
                    
                    let keyEntities = keysSet.compactMap { $0 as? LocalInfectionKeyEntity }
                    
                    let localData: Set<Data> = Set(keyEntities.compactMap { $0.temporaryExposureKey?.networkData })
                    
                    if keyData.intersection(localData).count > 0 {
                        approvedEntities.append(entity)
                    }
                }
                
                if approvedEntities.count > 0 {
                    approvedEntities.forEach { entity in
                        entity.status = InfectionStatus.submittedApproved.rawValue
                    }
                    
                    localInfectionsUpdated = true
                }
            }
            catch {
                
            }
            
            
            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
            
            let date = Date()
                
            var numNewKeys = 0

            for key in keys {
                
                let data = key.keyData
                
                request.predicate = NSPredicate(format: "infectedKey = %@ AND rollingStartNumber = %@", data as CVarArg, Int64(key.rollingStartNumber) as NSNumber)
                
                do {
                    let count = try context.count(for: request)
                    let alreadyHasKey = count > 0
                    
                    if !alreadyHasKey {
                        let entity = RemoteInfectedKeyEntity(context: context)
                        entity.dateAdded = date
                        entity.infectedKey = data
                        // Core data doesn't support unsigned ints, so using Int64 instead of UInt32
                        entity.rollingStartNumber = Int64(key.rollingStartNumber)
                        
                        numNewKeys += 1
                    }
                }
                catch {
                    completion(0, error)
                    return
                }
            }
            
            do {
                if context.hasChanges {
                    try context.save()
                }
                
                if localInfectionsUpdated {
                    NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                }
                
                completion(numNewKeys, nil)
            }
            catch {
                completion(numNewKeys, error)
            }
        }
    }
    
    func allInfectedKeys(completion: @escaping ([TemporaryExposureKey]?, Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            let request: NSFetchRequest<RemoteInfectedKeyEntity> = RemoteInfectedKeyEntity.fetchRequest()
            
            do {
                let entities = try context.fetch(request)
                
                let keys: [TemporaryExposureKey] = entities.compactMap { $0.temporaryExposureKey }
                completion(keys, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}

extension RemoteInfectedKeyEntity {
    var temporaryExposureKey: DataManager.TemporaryExposureKey? {
        guard let keyData = self.infectedKey else {
            return nil
        }
        
        return .init(
            keyData: keyData,
            rollingStartNumber: ENIntervalNumber(self.rollingStartNumber)
        )
    }
}

extension LocalInfectionKeyEntity {
    var temporaryExposureKey: DataManager.TemporaryExposureKey? {
        guard let keyData = self.infectedKey else {
            return nil
        }
        
        return .init(
            keyData: keyData,
            rollingStartNumber: ENIntervalNumber(self.rollingStartNumber)
        )
    }
}

extension DataManager {
    func submitReport(formData: InfectedKeysFormData, keys: [DataManager.TemporaryExposureKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            // Putting this as pending effectively saves a draft in case something goes wrong in submission
            
            let entity = LocalInfectionEntity(context: context)
            entity.dateAdded = Date()
            entity.status = DataManager.InfectionStatus.pendingSubmission.rawValue
            
            try? context.save()
        
            NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)

            KeyServer.shared.submitInfectedKeys(formData: formData, keys: keys, previousSubmissionId: nil) { success, submissionId, error in
                
                context.perform {
                    if success {
                        // XXX: Check against the local database to see if it should be submittedApproved or submittedUnapproved.
                        entity.status = DataManager.InfectionStatus.submittedUnapproved.rawValue
                        entity.remoteIdentifier = submissionId
                        
                        for key in keys {
                            let keyEntity = LocalInfectionKeyEntity(context: context)
                            keyEntity.infectedKey = key.keyData
                            keyEntity.rollingStartNumber = Int64(key.rollingStartNumber)
                            keyEntity.infection = entity
                        }

                        try? context.save()
                        
                        NotificationCenter.default.post(name: DataManager.infectionsUpdatedNotification, object: nil)
                        
                        completion(true, nil)
                    }
                    else {
                        completion(false, error)
                    }
                }
            }
        }

    }
}

extension DataManager {
    enum InfectionStatus: String {
        case pendingSubmission = "P"
        case submittedUnapproved = "U" // Submitted but hasn't been received back as an infected key
        case submittedApproved = "S" // Submitted and seen in the remote infection list
    }
}

extension DataManager {
    // Other statuses could be added here to allow the user to flag each
    // exposure with a level of confidence. For example, maybe they know
    // for a fact they were in their car alone, so they could mark an
    // exposure as not possible
    enum ExposureStatus: String {
        case detected = "D"
    }
    
    enum ExposureLocalNotificationStatus: String {
        case notSent = "P"
        case sent = "S"
    }
    
    func saveExposures(exposures: [ENExposureInfo], completion: @escaping (Error?) -> Void) {
        
        let context = self.persistentContainer.newBackgroundContext()
        
        context.perform {
            
            var delete: [ExposureContactInfoEntity] = []
            var insert: [ENExposureInfo] = []

            do {
                let request = ExposureFetchRequest(includeStatuses: [], includeNotificationStatuses: [], sortDirection: nil)
                let existingEntities = try context.fetch(request.fetchRequest)
                
                for entity in existingEntities {
                    var found = false
                    
                    for exposure in exposures {
                        if entity.matches(exposure: exposure) {
                            found = true
                            break
                        }
                    }
                    
                    if found {
                        // Already have this contact
                        print("Contact already exists, skipping")
                    }
                    else {
                        print("Contact not found in new list, deleting: \(entity)")
                        delete.append(entity)
                    }
                }
                
                for exposure in exposures {
                    var found = false
                    
                    for entity in existingEntities {
                        if entity.matches(exposure: exposure) {
                            found = true
                            break
                        }
                    }
                    
                    if found {
                        // Already have this contact
                    }
                    else {
                        print("New exposure detected: \(exposure)")
                        insert.append(exposure)
                    }
                }
                
                print("Deleting: \(delete.count)")
                print("Inserting: \(insert.count)")

                delete.forEach { context.delete($0) }

                for contact in insert {
                    let entity = ExposureContactInfoEntity(context: context)
                    entity.timestamp = contact.date
                    entity.duration = contact.duration
                    entity.attenuationValue = Int16(contact.attenuationValue)
                    
                    entity.status = ExposureStatus.detected.rawValue
                    entity.localNotificationStatus = ExposureLocalNotificationStatus.notSent.rawValue
                }
                
                try context.save()
                
                NotificationCenter.default.post(name: Self.exposureContactsUpdatedNotification, object: nil)
                
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
        
    }
}

extension DataManager {
    enum DiseaseStatus {
        case nothingDetected
        case exposed
        case infection
        case infectionPending
        case infectionPendingAndExposed
    }
    
    func diseaseStatus(context: NSManagedObjectContext) -> DiseaseStatus {
        let exposureRequest = ExposureFetchRequest(includeStatuses: [ .detected ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        let numContacts = (try? context.count(for: exposureRequest.fetchRequest)) ?? 0
        
        let infectionRequest = InfectionFetchRequest(minDate: nil, includeStatuses: [ .submittedApproved, .submittedUnapproved ])
        
        var hasPending = false
        var hasApproved = false
        
        do {
            let infections = try context.fetch(infectionRequest.fetchRequest)

            infections.forEach { infection in
                switch infection.status {
                case InfectionStatus.submittedUnapproved.rawValue:
                    hasPending = true
                case InfectionStatus.submittedApproved.rawValue:
                    hasApproved = true
                default:
                    break
                }
            }
            
        }
        catch {

        }
        
        if hasPending {
            if numContacts > 0 {
                return .infectionPendingAndExposed
            }
            else {
                return .infectionPending
            }
        }
        else if hasApproved {
            return .infection
        }
        else if numContacts > 0 {
            return .exposed
        }
        else {
            return .nothingDetected
        }
    }
}

extension ExposureContactInfoEntity {
    var contactInfo: DataManager.ExposureInfo? {
        guard let timestamp = self.timestamp else {
            return nil
        }
        
        return .init(
            attenuationValue: UInt8(self.attenuationValue),
            date: timestamp,
            duration: self.duration,
            totalRiskScore: .zero, // TODO: Fix
            transmissionRiskLevel: .low // TODO: Fix
        )
    }
    
    func matches(exposure: ENExposureInfo) -> Bool {
        if exposure.attenuationValue != UInt8(self.attenuationValue) {
            return false
        }
        
        if exposure.duration != self.duration {
            return false
        }
        
        if exposure.date != self.timestamp {
            return false
        }
        
        return true
    }
}

struct ExposureFetchRequest {
    enum SortDirection {
        case timestampAsc
        case timestampDesc

        var sortDescriptors: [NSSortDescriptor] {
            switch self {
            case .timestampAsc:
                return [
                    NSSortDescriptor(key: "timestamp", ascending: true),
                    NSSortDescriptor(key: "duration", ascending: false)
                ]
            case .timestampDesc:
                return [
                    NSSortDescriptor(key: "timestamp", ascending: false),
                    NSSortDescriptor(key: "duration", ascending: true)
                ]
            }
        }
    }
    
    let includeStatuses: Set<DataManager.ExposureStatus>
    let includeNotificationStatuses: Set<DataManager.ExposureLocalNotificationStatus>
    let sortDirection: SortDirection?
    
    var fetchRequest: NSFetchRequest<ExposureContactInfoEntity> {
        
        let fetchRequest: NSFetchRequest<ExposureContactInfoEntity> = ExposureContactInfoEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []

        if includeStatuses.count > 0 {
            predicates.append(NSPredicate(format: "status IN %@", includeStatuses.map { $0.rawValue }))
        }
        
        if includeNotificationStatuses.count > 0 {
            predicates.append(NSPredicate(format: "localNotificationStatus IN %@", includeNotificationStatuses.map { $0.rawValue }))
        }
        
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        if let sortDirection = sortDirection {
            fetchRequest.sortDescriptors = sortDirection.sortDescriptors
        }

        return fetchRequest
    }
}

struct InfectionFetchRequest {
    let minDate: Date?
    let includeStatuses: Set<DataManager.InfectionStatus>

    var fetchRequest: NSFetchRequest<LocalInfectionEntity> {
        
        let fetchRequest: NSFetchRequest<LocalInfectionEntity> = LocalInfectionEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if includeStatuses.count > 0 {
            predicates.append(NSPredicate(format: "status IN %@", includeStatuses.map { $0.rawValue }))
        }
        
        if let minDate = minDate {
            predicates.append(NSPredicate(format: "dateAdded >= %@", minDate as CVarArg))
        }
        
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        return fetchRequest
    }
}
